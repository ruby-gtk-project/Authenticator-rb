# frozen_string_literal: true

require "json"

require_relative "account"
require_relative "accounts_manager"
require_relative "gpg"
require_relative "logger"

module Authenticator
  # Backup imports and exports accounts as andOTP-compatible JSON.
  #
  # Ported from Authenticator/models/backup.py. Upstream's Backup.
  # import_accounts reaches into the AccountsWidget singleton to append each
  # new row; the port takes the append as a block instead, so the model does
  # not need to know a widget exists.
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

  # BackupPgpJson is the OpenPGP-encrypted backup format.
  #
  # Ported from the BackupPGPJSON class of Authenticator/models/backup.py,
  # which has only an export: the plain JSON is encrypted to a fingerprint and
  # the armoured ciphertext written out. The matching import belongs to
  # GpgRestoreWindow, which asks for the passphrase, decrypts to a temporary
  # file and hands that to BackupJson above — the same split upstream makes.
  #
  # `export_file` returns whether it wrote anything, which upstream's caller
  # has no way to ask: it writes `str()` of python-gnupg's result whatever that
  # result says, so a failed encrypt leaves an empty file behind that looks
  # like a backup. The port writes the file only once gpg has said the
  # ciphertext is good.
  class BackupPgpJson
    class << self
      def export_file(filename, fingerprint)
        Gpg.default.encrypt_json(
          "#{JSON.pretty_generate(Backup.export_accounts)}\n",
          fingerprint,
        ).then do |status|
          if status.ok
            File.write(filename, status.data)
            true
          else
            Logger.error("[Backup] Could not encrypt the backup to #{fingerprint}")
            false
          end
        end
      end
    end
  end
end
