# frozen_string_literal: true

require "cgi"
require "open3"
require "uri"

require_relative "logger"
require_relative "otp"

module Authenticator
  # QrReader reads an `otpauth://` URI out of a QR-code image and hands back
  # the secret token in it.
  #
  # Ported from Authenticator/models/qr_reader.py. Upstream decodes the image
  # with pyzbar over a PIL Image, deletes the file it read, parses the decoded
  # URI's query string into a dict and returns its "secret"; `is_valid` then
  # asks the OTP model whether a code can be generated from that secret. When
  # pyzbar or PIL is missing it catches the ImportError, sets its own
  # ZBAR_FOUND to False and turns the application's USE_QRSCANNER off, so the
  # scan button disappears rather than failing when pressed.
  #
  # pyzbar is a binding to libzbar, and there is no such gem in this project's
  # bundle. zbar ships `zbarimg`, which is the same decoder over the same
  # library behind a command line, so that is what this drives — and
  # `available?` is upstream's ZBAR_FOUND, asked of PATH rather than of a
  # failed import. The dev shell carries zbar for it.
  class QrReader
    # The decoder, and the arguments that make it machine-readable: `-q`
    # silences its summary, `--raw` prints the payload without zbar's
    # "QR-Code:" prefix, and `-Sdisable -Sqrcode.enable` narrows it to QR
    # codes, which is the only symbology an otpauth URI ever arrives in.
    BINARY = "zbarimg"
    ARGS = %w[-q --raw -Sdisable -Sqrcode.enable].freeze

    # The whole of the decoded URI's query string, which is what upstream
    # keeps in its `_codes`. The issuer and the digit count live here too, and
    # upstream reads only "secret" off it.
    attr_reader :codes

    class << self
      # Upstream's ZBAR_FOUND: whether there is a decoder to drive at all.
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

    def initialize(filename)
      @filename = filename
      @codes = nil
    end

    # Upstream's read(): the secret from the image, or nil when the image held
    # no QR code, when the code was not an otpauth URI, or when there is no
    # decoder. The file is deleted either way, as upstream deletes it — it is
    # a screenshot of the user's secret and has no business outliving the
    # read.
    def read
      self.class.available?.then do |decoder|
        unless decoder
          Logger.error("[QRReader] #{BINARY} is not installed, so QR scanning is unavailable")
        end
        if decoder
          decode.then do |payload|
            discard
            if payload
              @codes = query_params(payload)
              @codes["secret"]
            else
              Logger.error("Invalid QR image")
              nil
            end
          end
        end
      end
    end

    # Upstream's is_valid(): whether what was read is a usable two-factor
    # token. False before `read` has run, as upstream's is.
    def valid?
      @codes.is_a?(Hash).then do |read_already|
        if read_already
          OTP.valid?(@codes["secret"])
        else
          false
        end
      end
    end

    private

      # The payload of the first QR code in the image, or nil when there was
      # none. zbarimg exits 4 when it found nothing to decode, so a missing
      # code is not an error to log twice.
      def decode
        Open3.capture3(BINARY, *ARGS, @filename.to_s).then do |stdout, stderr, status|
          if status.success? && !stdout.strip.empty?
            stdout.lines.first.to_s.strip
          else
            Logger.debug("[QRReader] #{BINARY} read nothing from #{@filename}: #{stderr.strip}")
            nil
          end
        end
      rescue Errno::ENOENT
        nil
      end

      # Upstream's urlparse plus parse_qsl: the query string of the decoded
      # URI as a hash. A payload that is not a URI at all parses to an empty
      # hash, which is what makes `valid?` false for it.
      def query_params(payload)
        URI.parse(payload).query.to_s.then do |query|
          CGI.parse(query).transform_values(&:first)
        end
      rescue URI::InvalidURIError => e
        Logger.error("[QRReader] #{payload.inspect} is not a URI: #{e.message}")
        {}
      end

      def discard
        File.file?(@filename.to_s).then do |exists|
          if exists
            File.unlink(@filename)
          end
        end
      end
  end
end
