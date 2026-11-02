# frozen_string_literal: true

require "digest"

require_relative "clipboard"
require_relative "database"
require_relative "keyring"
require_relative "logger"
require_relative "otp"

module Authenticator
  # Account is one two-factor account: a username, the provider it belongs to,
  # and the secret id under which its OTP token is kept in the Keyring.
  #
  # Ported from Authenticator/models/account.py. Upstream is a GObject with
  # three signals — `otp_out_of_date`, `otp_updated(str)` and `removed` — that
  # the AccountsManager emits on a timer and the row widget listens to. The
  # port keeps the same three as plain callback registrations rather than
  # registering a GObject type: nothing passes an Account through a GObject
  # property or a Gio::ListModel, so a registered type would buy nothing and
  # cost the type_register dance.
  class Account
    attr_reader :id, :username, :secret_id, :otp
    attr_accessor :provider

    class << self
      # Creates and persists a new account: the secret id is the SHA-256 of
      # the token, the record goes in the database and the token in the
      # keyring. Returns nil when the database refused the record, which it
      # does when that token is already stored.
      def create(username, provider, token)
        Digest::SHA256.hexdigest(token.to_s).then do |secret_id|
          Database.default.insert(username, provider, secret_id).then do |row|
            if row
              Keyring.insert(
                secret_id,
                provider,
                username,
                token,
              )
              new(
                row["id"],
                username,
                provider,
                secret_id,
              )
            end
          end
        end
      end

      # Creates an account from one entry of a backup file. Upstream takes the
      # provider from the first of the entry's "tags", defaulting to
      # "Default".
      def create_from_json(json_obj)
        Array(json_obj["tags"]).first.to_s.strip.then do |tag|
          if tag.empty?
            create(json_obj["label"], "Default", json_obj["secret"])
          else
            create(json_obj["label"], tag, json_obj["secret"])
          end
        end
      end

      def get_by_id(id)
        Database.default.get_by_id(id).then do |row|
          if row
            new(
              row["id"],
              row["username"],
              row["provider"],
              row["secret_id"],
            )
          end
        end
      end
    end

    def initialize(id, username, provider, secret_id)
      @id = id
      @username = username
      @provider = provider
      @secret_id = secret_id
      @otp_updated_callbacks = []
      @removed_callbacks = []
      @otp = build_otp
      @code_generated = !@otp.nil?
    end

    # Registers a listener for upstream's `otp_updated` signal.
    def on_otp_updated(&block) = @otp_updated_callbacks << block

    # Registers a listener for upstream's `removed` signal.
    def on_removed(&block) = @removed_callbacks << block

    # Upstream's `otp_out_of_date` handler: regenerate the code and tell the
    # listeners about it. The AccountsManager calls this once a period.
    def otp_out_of_date
      @code_generated.then do |generated|
        if generated
          @otp.update
          @otp_updated_callbacks.each { |callback| callback.call(@otp.pin) }
        end
      end
    end

    # The code the row shows. nil when the token could not be decoded, which
    # upstream renders as "??????".
    def pin = @otp&.pin

    def update(username, provider)
      @username = username
      @provider = provider
      Database.default.update(username, provider, @id)
    end

    def remove
      Database.default.remove(@id)
      Keyring.remove(@secret_id)
      @removed_callbacks.each(&:call)
      Logger.debug("Account '#{@username}' with id #{@id} was removed")
    end

    def copy_pin
      Clipboard.set(@otp&.pin)
    end

    # One entry of a backup file, in upstream's andOTP-compatible shape.
    # Returns nil when the token has gone from the keyring, which is what
    # makes such an account skipped on export rather than exported empty.
    def to_json_hash
      Keyring.get_by_id(@secret_id).then do |token|
        if token
          {
            "secret"    => token,
            "label"     => @username,
            "period"    => OTP::PERIOD,
            "digits"    => OTP::DIGITS,
            "type"      => "OTP",
            "algorithm" => "SHA1",
            "thumbnail" => "Default",
            "last_used" => 0,
            "tags"      => [@provider],
          }
        end
      end
    end

    private

      def build_otp
        Keyring.get_by_id(@secret_id).then do |token|
          if token
            OTP.new(token)
          else
            Logger.error(
              "Could not read the secret code, the keyring keys were reset manually",
            )
            nil
          end
        end
      end
  end
end
