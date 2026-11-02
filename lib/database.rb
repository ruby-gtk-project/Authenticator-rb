# frozen_string_literal: true

require "json"
require "fileutils"

require_relative "logger"

module Authenticator
  # Database is the account store: the id, username, provider and secret id of
  # every account. The secret token itself lives in the Keyring, never here.
  #
  # Ported from Authenticator/models/database.py. Upstream keeps a single
  # `accounts` table in SQLite at
  # $XDG_CONFIG_HOME/Authenticator/database-4.db with the columns
  #
  #   id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL UNIQUE
  #   username VARCHAR NOT NULL
  #   provider VARCHAR NOT NULL
  #   secret_id VARCHAR NOT NULL UNIQUE
  #
  # and reads it back ordered by provider ascending, username descending.
  # There is no sqlite3 gem in this project's bundle, so the same records,
  # the same uniqueness rules, the same autoincrementing ids and the same
  # ordering are kept in a JSON file next to upstream's, named for the same
  # schema version. Every method below is one of upstream's, with upstream's
  # return shape.
  class Database
    # Upstream's Database.db_version. Bumping it starts a fresh store, which
    # is the whole point of its being in the filename.
    DB_VERSION = 4

    class << self
      def default = @default ||= new

      # Lets a spec point the singleton at a throwaway file.
      attr_writer :default

      def db_file
        File.join(
          ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config")),
          "authenticator-rb",
          "database-#{DB_VERSION}.json",
        )
      end
    end

    def initialize(path: nil)
      @path = path || self.class.db_file
      @rows = read
    end

    def location = @path

    # Inserts an account and returns it. Upstream returns an OrderedDict
    # whose second key is "name" rather than "username" — a typo it gets away
    # with because Account.create only reads ["id"] off it. The port returns
    # "username", which is the name every other method here uses.
    def insert(username, provider, secret_id)
      @rows.any? { |row| row["secret_id"] == secret_id.to_s }.then do |duplicate|
        if duplicate
          Logger.error("[DB] Couldn't add a new account: secret_id is already stored")
          nil
        else
          {
            "id"        => next_id,
            "username"  => username.to_s,
            "provider"  => provider.to_s,
            "secret_id" => secret_id.to_s,
          }.tap do |row|
            @rows << row
            write
          end
        end
      end
    end

    def get_by_id(id)
      @rows.find { |row| row["id"] == id.to_i }.then do |row|
        if row
          row.dup
        else
          Logger.error("[DB] Couldn't get account with ID=#{id}")
          nil
        end
      end
    end

    def get_secret_id(id) = get_by_id(id)&.fetch("secret_id", nil)

    def remove(id)
      @rows.reject! { |row| row["id"] == id.to_i }.then do |removed|
        if removed
          write
        else
          Logger.error("[DB] Couldn't remove the account '#{id}'")
        end
      end
    end

    # Removes every account, as upstream's clear() does.
    def clear
      @rows = []
      write
    end

    def update(username, provider, id)
      @rows.find { |row| row["id"] == id.to_i }.then do |row|
        if row
          row["username"] = username.to_s
          row["provider"] = provider.to_s
          write
        else
          Logger.error("[DB] Couldn't update account name by id")
        end
      end
    end

    # Upstream's LIKE '%terms%' search over usernames, returning ids as
    # strings because that is what its shell search provider hands back over
    # D-Bus.
    def search(terms)
      Array(terms).join(" ").strip.downcase.then do |filter|
        @rows.select { |row|
          row["username"].to_s.downcase.include?(filter)
        }.map { |row| row["id"].to_s }
      end
    end

    def count = @rows.length

    # Ordered provider ascending, username descending — upstream's
    # "ORDER BY provider ASC, username DESC".
    def accounts
      @rows.sort do |a, b|
        [a["provider"].to_s, b["username"].to_s] <=> [b["provider"].to_s, a["username"].to_s]
      end.map(&:dup)
    end

    def latest_id = @rows.map { |row| row["id"].to_i }.max

    private

      def next_id = (latest_id || 0) + 1

      def read
        File.exist?(@path).then do |exists|
          if exists
            Array(JSON.parse(File.read(@path)).fetch("accounts", []))
          else
            []
          end
        end
      rescue JSON::ParserError => e
        Logger.error("[DB] Could not parse #{@path}: #{e.message}")
        []
      end

      def write
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.pretty_generate({ "version" => DB_VERSION, "accounts" => @rows }))
      end
  end
end
