# frozen_string_literal: true

require "json"

require_relative "account"
require_relative "accounts_manager"
require_relative "logger"

module Authenticator
  # Backup imports and exports accounts as andOTP-compatible JSON.
  #
  # Ported from Authenticator/models/backup.py. Upstream's Backup.
  # import_accounts reaches into the AccountsWidget singleton to append each
  # new row; the port takes the append as a block instead, so the model does
  # not need to know a widget exists. BackupPGPJSON is not ported this round —
  # it needs the GPG model, and there is no gpg in this project's dev shell to
  # drive.
  class Backup
    class << self
      # Creates an account per backup entry, handing each one to the block so
      # the caller can show it. Upstream swallows every per-entry failure so
      # one bad record does not abort the import; the port logs what it
      # swallowed.
      def import_accounts(accounts, &on_imported)
        Array(accounts).each do |entry|
          Account.create_from_json(entry).then do |account|
            if account
              AccountsManager.default.add(account)
              on_imported&.call(account)
            end
          end
        rescue StandardError => e
          Logger.error("[Backup] Skipped an account during import: #{e.message}")
        end
      end

      # Every loaded account as a backup entry, skipping the ones whose token
      # has gone from the keyring.
      def export_accounts
        AccountsManager.default.accounts.filter_map(&:to_json_hash)
      end
    end
  end

  # BackupJson is the plain-text JSON backup format.
  #
  # Ported from the BackupJSON class of Authenticator/models/backup.py.
  class BackupJson
    class << self
      def export_file(filename)
        File.write(filename, "#{JSON.pretty_generate(Backup.export_accounts)}\n")
      end

      def import_file(filename, &on_imported)
        Backup.import_accounts(JSON.parse(File.read(filename)), &on_imported)
      rescue JSON::ParserError => e
        Logger.error("[Backup] #{filename} is not valid JSON: #{e.message}")
      end
    end
  end
end
