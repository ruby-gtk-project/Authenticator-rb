# frozen_string_literal: true

require "json"
require "fileutils"

require_relative "logger"

module Authenticator
  # Keyring stores the OTP secret tokens, keyed by the secret id the Account
  # model derives from the token.
  #
  # Ported from Authenticator/models/keyring.py. Upstream talks to
  # libsecret through its GObject-Introspection binding (`Secret-1`), storing
  # each token against a two-attribute schema ("id", "name") in the login
  # collection.
  #
  # The Secret-1 typelib is not among the ones this project's dev shell
  # provides, so there is no libsecret to bind to and the tokens are kept in a
  # file under XDG_DATA_HOME instead, created mode 0600 and written through a
  # 0600 temporary file so a token is never briefly world-readable. That is
  # weaker than a locked keyring — the file is readable by anything running as
  # the user — and upstream's attribute schema is reproduced as the file's
  # record shape so a later round can swap libsecret in underneath without the
  # callers changing.
  class Keyring
    # Upstream's schema name, kept as the file's schema marker.
    ID = "com.github.bilelmoussaoui.Authenticator"

    class << self
      def default = @default ||= new

      # Lets a spec point the singleton at a throwaway file.
      attr_writer :default

      def get_by_id(secret_id) = default.get_by_id(secret_id)

      def insert(secret_id, provider, username, token)
        default.insert(
          secret_id,
          provider,
          username,
          token,
        )
      end

      def remove(secret_id) = default.remove(secret_id)
      def clear = default.clear

      def default_path
        File.join(
          ENV.fetch("XDG_DATA_HOME", File.expand_path("~/.local/share")),
          "authenticator-rb",
          "keyring.json",
        )
      end
    end

    def initialize(path: nil)
      @path = path || self.class.default_path
      @records = read
    end

    def location = @path

    # Returns the OTP token for a secret id, or nil when the record is gone —
    # which is the case upstream logs as "the keyring keys were reset
    # manually".
    def get_by_id(secret_id)
      @records.dig(secret_id.to_s, "token")
    end

    # Stores a token. `provider` and `username` only make the stored record
    # legible, exactly as they only make up the label upstream passes to
    # libsecret: "{provider} OTP ({username})".
    def insert(secret_id, provider, username, token)
      @records[secret_id.to_s] = {
        "id"    => secret_id.to_s,
        "name"  => username.to_s,
        "label" => "#{provider} OTP (#{username})",
        "token" => token.to_s,
      }
      write
      token
    end

    def remove(secret_id)
      @records.delete(secret_id.to_s).then do |removed|
        write
        !removed.nil?
      end
    end

    def clear
      @records = {}
      write
      true
    end

    private

      def read
        File.exist?(@path).then do |exists|
          if exists
            JSON.parse(File.read(@path)).fetch("records", {})
          else
            {}
          end
        end
      rescue JSON::ParserError => e
        Logger.error("[Keyring] Could not parse #{@path}: #{e.message}")
        {}
      end

      def write
        FileUtils.mkdir_p(File.dirname(@path), mode: 0o700)
        "#{@path}.tmp".then do |tmp|
          File.open(tmp, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
            file.write(JSON.pretty_generate({ "schema" => ID, "records" => @records }))
          end
          File.rename(tmp, @path)
        end
      end
  end
end
