# frozen_string_literal: true

require "openssl"

module Authenticator
  # OTP is the one-time-password generator.
  #
  # Ported from Authenticator/models/otp.py. Upstream subclasses PyOTP's TOTP
  # and keeps the current code in a `pin` attribute refreshed by `update()`;
  # that is the interface the rest of the app uses, so it is the interface
  # kept here. PyOTP has no Ruby equivalent in this project's bundle, so the
  # RFC 4648 base32 decode and the RFC 6238 TOTP itself are implemented here
  # over OpenSSL's HMAC — about thirty lines, and verified against the test
  # vectors in RFC 6238 appendix B.
  class OTP
    # PyOTP's TOTP defaults, which upstream never overrides.
    PERIOD = 30
    DIGITS = 6
    DIGEST = "sha1"

    BASE32_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"

    # The current code, or nil when the token could not be decoded. Upstream
    # leaves `pin` nil in exactly that case and the row widget renders
    # "??????" for it.
    attr_reader :pin

    class << self
      # Validates an OTP token, as upstream's OTP.is_valid does: a token is
      # valid when a code can be generated from it.
      def valid?(token)
        !new(token).pin.nil?
      end

      # Decodes an RFC 4648 base32 string, ignoring the padding, the spaces
      # users paste along with their secrets, and case. Raises ArgumentError
      # on any character outside the alphabet, which is what makes an invalid
      # token detectable.
      def decode_base32(token)
        token.to_s.upcase.gsub(/[\s=-]/, "").then do |cleaned|
          if cleaned.empty?
            raise ArgumentError, "empty base32 string"
          end

          cleaned.each_char.map { |char|
            BASE32_ALPHABET.index(char) || raise(ArgumentError, "invalid base32 character #{char.inspect}")
          }.map { |index| format("%05b", index) }
            .join
            .then { |bits| [bits[0, (bits.length / 8) * 8].to_s].pack("B*") }
        end
      end
    end

    def initialize(token, period: PERIOD, digits: DIGITS, digest: DIGEST)
      @token = token
      @period = period
      @digits = digits
      @digest = digest
      update
    end

    # Generates the code for a point in time, defaulting to now. Upstream
    # calls PyOTP's `now()` with no argument; the parameter is what lets the
    # specs check a code against a fixed timestamp.
    def at(time = Time.now)
      counter(time).then do |count|
        OpenSSL::HMAC.digest(OpenSSL::Digest.new(@digest), secret, [count].pack("Q>")).then do |hmac|
          truncate(hmac)
        end
      end
    rescue ArgumentError
      nil
    end

    # Regenerates the code from the same token, as upstream's update() does.
    def update
      @pin = at
    end

    # Seconds remaining before the current code expires. Upstream's
    # AccountsManager owns this counter instead, but the arithmetic belongs
    # with the generator.
    def remaining(time = Time.now) = @period - (time.to_i % @period)

    private

      def secret = @secret ||= self.class.decode_base32(@token)

      def counter(time) = time.to_i / @period

      # RFC 6238's dynamic truncation.
      def truncate(hmac)
        (hmac[-1].ord & 0xf).then do |offset|
          (hmac[offset, 4].unpack1("N") & 0x7fffffff).then do |code|
            format("%0#{@digits}d", code % (10**@digits))
          end
        end
      end
  end
end
