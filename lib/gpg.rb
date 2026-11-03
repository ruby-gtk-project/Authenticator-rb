# frozen_string_literal: true

require "fileutils"
require "open3"

require_relative "logger"
require_relative "settings"

module Authenticator
  # Gpg is the OpenPGP backend: it lists the keys in the user's keyring and
  # encrypts and decrypts the JSON backups with them.
  #
  # Ported from Authenticator/models/gnupg.py. Upstream subclasses
  # python-gnupg's GPG, pointed at `Settings.get_default().gpg_location` as its
  # `gnupghome`, and uses four of its methods: list_keys, list_keys(True),
  # decrypt_file and encrypt.
  #
  # python-gnupg is itself nothing but a driver for the `gpg` binary: it spawns
  # it with `--batch` and parses the machine-readable output back. There is no
  # such gem in this project's bundle, so this class drives the same binary,
  # reading the key listings out of `--with-colons`, which is gpg's documented
  # stable output format. The dev shell carries gnupg for exactly this, and
  # `available?` below is how the windows ask whether it is there before
  # offering to use it.
  class Gpg
    # The binary, and the arguments every invocation carries. `--batch` and
    # `--yes` keep gpg from ever opening a prompt of its own, which would hang
    # the app; `--pinentry-mode loopback` is what makes gpg take the
    # passphrase from the pipe below instead of from a pinentry dialog.
    BINARY = "gpg"
    COMMON_ARGS = %w[--batch --yes --no-tty --pinentry-mode loopback].freeze

    # gpg's `--with-colons` record types, and the fields of each one this
    # reads. See doc/DETAILS in the gnupg source: field 1 is the record type,
    # field 5 of a `pub`/`sec` record is the key id, field 10 of a `fpr`
    # record is the fingerprint, and field 10 of a `uid` record is the user
    # id.
    PUBLIC_KEY_RECORD = "pub"
    SECRET_KEY_RECORD = "sec"
    FINGERPRINT_RECORD = "fpr"
    UID_RECORD = "uid"

    # What `decrypt_json` and `encrypt_json` hand back. Upstream's callers
    # read `status.ok` off python-gnupg's result object, and read `str()` off
    # the same object to get the armoured ciphertext; `data` is that string on
    # success and gpg's complaint on failure.
    Status = Struct.new(:ok, :data)

    class << self
      def default = @default ||= new

      # Lets a spec, or a drive script, point the singleton at a throwaway
      # keyring.
      attr_writer :default

      # Whether there is a gpg to drive at all. Upstream has the equivalent
      # question — python-gnupg raises OSError from its constructor when the
      # binary is missing — and the windows below ask it so they can say so
      # rather than fail silently.
      def available?
        !which.nil?
      end

      def which
        ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).filter_map { |dir|
          File.join(dir, BINARY).then do |candidate|
            candidate if File.executable?(candidate) && !File.directory?(candidate)
          end
        }.first
      end
    end

    def initialize(home: nil)
      @home = home
    end

    # Where gpg keeps its keyring, which is upstream's `gnupghome`. Expanded
    # because the schema's default is the literal "~/.gnupg/" and gpg does no
    # tilde expansion of its own.
    def home = File.expand_path(@home || Settings.default.gpg_location)

    # Upstream's get_keys: the public keys under "public", the secret ones
    # under "private". Each key is a hash with the "uids" and "fingerprint"
    # that FingerprintPGPWindow reads off it, so the shape python-gnupg
    # produces is the shape kept here.
    def keys
      {
        "public"  => list_keys(secret: false),
        "private" => list_keys(secret: true),
      }
    end

    # Upstream's list_keys. `secret` picks `--list-secret-keys` over
    # `--list-keys`, which is what python-gnupg's boolean argument does.
    def list_keys(secret: false)
      run(secret ? "--list-secret-keys" : "--list-keys", "--with-colons").then do |stdout, _stderr, ok|
        if ok
          parse_colons(stdout, secret ? SECRET_KEY_RECORD : PUBLIC_KEY_RECORD)
        else
          []
        end
      end
    end

    # Upstream's decrypt_json: decrypt `filename` with `passphrase` into
    # `out_file`, handing back something whose `ok` says whether it worked.
    def decrypt_json(filename, passphrase, out_file)
      FileUtils.mkdir_p(File.dirname(out_file))
      run(
        "--output", out_file,
        "--passphrase-fd", "0",
        "--decrypt", filename,
        stdin: "#{passphrase}\n",
      ).then do |_stdout, stderr, ok|
        # gpg writes a zero-length output file before it discovers the
        # passphrase is wrong, so a failed decrypt leaves a file behind that
        # would import as an empty backup. Clearing it is what keeps "ok" and
        # "there is something to import" the same question.
        unless ok
          FileUtils.rm_f(out_file)
          Logger.error("[GPG] Could not decrypt #{filename}: #{stderr.lines.last&.strip}")
        end
        Status.new(ok, stderr)
      end
    end

    # Upstream's ecrypt_json — its spelling, not a typo here — encrypts a JSON
    # string to a fingerprint. The armoured ciphertext comes back on the
    # status's `data`, which is where upstream's caller reads `str()` of
    # python-gnupg's result.
    def encrypt_json(json_obj, fingerprint)
      run(
        "--armor",
        "--trust-model", "always",
        "--recipient", fingerprint.to_s,
        "--encrypt",
        stdin: json_obj.to_s,
      ).then do |stdout, stderr, ok|
        unless ok
          Logger.error("[GPG] Could not encrypt to #{fingerprint}: #{stderr.lines.last&.strip}")
        end
        Status.new(ok, ok ? stdout : stderr)
      end
    end

    private

      # One gpg invocation, returning its stdout, its stderr and whether it
      # worked. Every invocation names the keyring home explicitly, as
      # upstream's `gnupghome` does, so the app never silently writes into the
      # default one.
      def run(*args, stdin: nil)
        [BINARY, "--homedir", home, *COMMON_ARGS, *args].then do |command|
          Open3.capture3(*command, stdin_data: stdin.to_s).then do |stdout, stderr, status|
            [stdout, stderr, status.success?]
          end
        end
      rescue Errno::ENOENT
        Logger.error("[GPG] #{BINARY} is not installed, so OpenPGP backups are unavailable")
        ["", "#{BINARY} is not installed", false]
      end

      # gpg's `--with-colons` listing, as the list of hashes python-gnupg
      # produces: every `pub` (or `sec`) record starts a key, the `fpr` record
      # that follows carries its fingerprint, and the `uid` records that
      # follow carry its user ids.
      def parse_colons(output, key_record)
        [].tap do |keys|
          output.each_line do |line|
            line.chomp.split(":", -1).then do |fields|
              case fields.first
              when key_record
                keys << { "keyid" => fields[4].to_s, "fingerprint" => "", "uids" => [] }
              when FINGERPRINT_RECORD
                keys.last.then do |key|
                  if key && key["fingerprint"].empty?
                    key["fingerprint"] = fields[9].to_s
                  end
                end
              when UID_RECORD
                keys.last&.fetch("uids")&.push(unescape(fields[9].to_s))
              end
            end
          end
        end
      end

      # gpg escapes a colon, a backslash and any non-printable byte in a
      # colon-delimited field as \xNN, which is what puts the user id's own
      # colons back.
      def unescape(field)
        field.gsub(/\\x([0-9a-fA-F]{2})/) { Regexp.last_match(1).hex.chr }
      end
  end
end
