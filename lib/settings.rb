# frozen_string_literal: true

require "json"
require "fileutils"

require_relative "logger"

module Authenticator
  # Settings holds the keys of upstream's GSettings schema.
  #
  # Ported from Authenticator/models/settings.py together with
  # data/com.github.bilelmoussaoui.Authenticator.gschema.xml, which is where
  # the keys, types and defaults below come from:
  #
  #   window-position  ai  [0,0]
  #   night-mode       b   false
  #   is-maximized     b   false
  #   gpg-location     s   '~/.gnupg/'
  #
  # Upstream subclasses Gio::Settings, which needs a compiled schema installed
  # into the system's glib-2.0/schemas directory before the app will even
  # start. Requiring an install step to run the port from a checkout is worse
  # than the alternative, so the same keys, defaults and semantics are backed
  # by a small JSON file under XDG_CONFIG_HOME instead — the same substitution
  # the pilot port makes.
  #
  # `backup-password` is not in upstream's schema even though
  # Authenticator/widgets/settings.py reads `Settings.get_default()
  # .backup_password` from its PasswordWindow; upstream's PasswordWindow is
  # never instantiated, so that read never runs. The port wires the window up,
  # so the key it needs is declared here.
  class Settings
    DEFAULTS = {
      "window-position" => [0, 0],
      "night-mode"      => false,
      "is-maximized"    => false,
      "gpg-location"    => "~/.gnupg/",
      "backup-password" => "",
    }.freeze

    class << self
      def default = @default ||= new

      # Lets a spec point the singleton at a throwaway file.
      attr_writer :default
    end

    def initialize(path: nil)
      @path = path || self.class.default_path
      @values = DEFAULTS.merge(read)
    end

    def location = @path

    def [](key) = @values.fetch(key.to_s, DEFAULTS[key.to_s])

    def []=(key, value)
      @values[key.to_s] = value
      write
      value
    end

    def self.default_path
      File.join(
        ENV.fetch("XDG_CONFIG_HOME", File.expand_path("~/.config")),
        "authenticator-rb",
        "settings.json",
      )
    end

    # Upstream exposes each key as a property with a bespoke name; the names
    # here are those properties, not the raw key strings.
    def window_position = Array(self["window-position"]).first(2).map(&:to_i)

    def window_position=(position)
      self["window-position"] = Array(position).first(2).map(&:to_i)
    end

    def night_mode? = self["night-mode"] == true

    def night_mode=(state)
      self["night-mode"] = (state == true)
    end

    def window_maximized? = self["is-maximized"] == true

    def window_maximized=(state)
      self["is-maximized"] = (state == true)
    end

    def gpg_location = self["gpg-location"].to_s

    def gpg_location=(location)
      self["gpg-location"] = location.to_s
    end

    def backup_password = self["backup-password"].to_s

    def backup_password=(password)
      self["backup-password"] = password.to_s
    end

    private

      def read
        File.exist?(@path).then do |exists|
          if exists
            JSON.parse(File.read(@path))
          else
            {}
          end
        end
      rescue JSON::ParserError => e
        Logger.error("[Settings] Could not parse #{@path}: #{e.message}")
        {}
      end

      def write
        FileUtils.mkdir_p(File.dirname(@path))
        File.write(@path, JSON.pretty_generate(@values))
      end
  end
end
