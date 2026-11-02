# frozen_string_literal: true

require "gtk4"

require_relative "account"
require_relative "database"

module Authenticator
  # AccountsManager owns the loaded accounts and the countdown that expires
  # their codes.
  #
  # Ported from Authenticator/models/accounts_manager.py. Upstream is a
  # GObject that is also a Thread: it loops once a second, decrements a
  # counter from 30, emits `counter_updated(str)` every tick, and on reaching
  # zero emits `otp_out_of_date` on every account so each regenerates its
  # code.
  #
  # The port runs that on a GLib timeout instead of a thread. Upstream's
  # thread emits GObject signals that widgets handle, which is a data race
  # against the main loop that only GTK 3's laxer threading model let it get
  # away with; a one-second timeout source gives the same tick on the thread
  # that owns the widgets.
  class AccountsManager
    COUNTER_MAX = 30

    attr_reader :counter, :counter_max

    class << self
      def default = @default ||= new

      # Lets a spec install a manager over a throwaway database, and lets the
      # application drop the singleton when the database is cleared.
      attr_writer :default
    end

    def initialize(start: true)
      @accounts = []
      @counter_updated_callbacks = []
      @counter_max = COUNTER_MAX
      @counter = COUNTER_MAX
      @source_id = nil
      fill_accounts
      start.then do |autostart|
        if autostart
          self.start
        end
      end
    end

    def accounts = @accounts

    def add(account) = @accounts << account

    def clear
      @accounts = []
    end

    # Registers a listener for upstream's `counter_updated` signal.
    def on_counter_updated(&block) = @counter_updated_callbacks << block

    # Starts the one-second tick. Returns the GLib source id.
    def start
      @source_id ||= GLib::Timeout.add_seconds(1) do
        tick
        GLib::Source::CONTINUE
      end
    end

    # Upstream's kill(): stop ticking. Called when the window closes.
    def kill
      @source_id.then do |id|
        if id
          GLib::Source.remove(id)
          @source_id = nil
        end
      end
    end

    # One second of upstream's run() loop, exposed so a spec can advance the
    # countdown without waiting on wall-clock time.
    def tick
      @counter -= 1
      (@counter <= 0).then do |expired|
        if expired
          @counter = @counter_max
          update_children
        end
      end
      @counter_updated_callbacks.each { |callback| callback.call(@counter) }
    end

    # Upstream's update_childes(): tell every account its code is stale.
    def update_children
      @accounts.each(&:otp_out_of_date)
    end

    private

      # Loads every stored account, skipping the ones whose token has gone
      # from the keyring — upstream's `if account.otp` guard.
      def fill_accounts
        Database.default.accounts.each do |row|
          Account.new(
            row["id"],
            row["username"],
            row["provider"],
            row["secret_id"],
          ).then do |account|
            if account.otp
              add(account)
            end
          end
        end
      end
  end
end
