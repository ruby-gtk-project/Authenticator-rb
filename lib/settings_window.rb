# frozen_string_literal: true

require "adwaita"
require "gettext"

require_relative "accounts_manager"
require_relative "clickable_settings_box"
require_relative "database"
require_relative "file_choosers"
require_relative "keyring"
require_relative "password_window"
require_relative "settings"
require_relative "switch_settings_box"

module Authenticator
  # SettingsWindow is the preferences window: Appearance, Behaviour and Backup.
  #
  # Ported from the SettingsWindow class of
  # Authenticator/widgets/settings.py. Upstream builds a Gtk::Stack with a
  # Gtk::StackSwitcher for a custom title; Adwaita::PreferencesWindow is that
  # arrangement, with the pages and the switcher built in, so the three stack
  # children become three preferences pages.
  #
  # Upstream's "clear the database" confirmation is a Gd::Notification with a
  # five-second Undo and a `dismissed` handler that does the clearing. libgd is
  # gone in GTK 4; an Adwaita toast is the same gesture — the same wording, the
  # same five seconds, the same Undo — and it is the window that shows it
  # rather than a widget pushed into the page.
  class SettingsWindow
    include GetText

    # Upstream's five seconds of grace before the accounts go.
    CLEAR_TIMEOUT = 5

    def initialize(parent, on_cleared: nil)
      @parent = parent
      @on_cleared = on_cleared
      @clear_cancelled = false
    end

    def build
      @build ||= window.tap do |win|
        win.transient_for = @parent
        win.add(appearance_page)
        win.add(behaviour_page)
        win.add(backup_page)

        appearance_page.tap do |page|
          page.add(appearance_group)

          appearance_group.tap do |group|
            group.add(dark_theme_row.build)
          end
        end

        behaviour_page.tap do |page|
          page.add(behaviour_group)

          behaviour_group.tap do |group|
            group.add(clear_database_row.build)
          end
        end

        backup_page.tap do |page|
          page.add(backup_group)

          backup_group.tap do |group|
            group.add(gpg_location_row.build)
            group.add(backup_password_row.build)
          end
        end
      end
    end

    def present
      build.present
    end

    def window
      @window ||= Adwaita::PreferencesWindow.new.tap do |win|
        win.title = _("Settings")
        win.modal = true
        win.search_enabled = false
        win.set_default_size(600, 600)
      end
    end

    def appearance_page
      @appearance_page ||= Adwaita::PreferencesPage.new.tap do |page|
        page.title = _("Appearance")
        page.name = "appearance"
        page.icon_name = "applications-graphics-symbolic"
      end
    end

    def behaviour_page
      @behaviour_page ||= Adwaita::PreferencesPage.new.tap do |page|
        page.title = _("Behaviour")
        page.name = "behaviour"
        page.icon_name = "preferences-other-symbolic"
      end
    end

    def backup_page
      @backup_page ||= Adwaita::PreferencesPage.new.tap do |page|
        page.title = _("Backup")
        page.name = "backup"
        page.icon_name = "document-save-symbolic"
      end
    end

    def appearance_group = @appearance_group ||= Adwaita::PreferencesGroup.new
    def behaviour_group = @behaviour_group ||= Adwaita::PreferencesGroup.new
    def backup_group = @backup_group ||= Adwaita::PreferencesGroup.new

    def dark_theme_row
      @dark_theme_row ||= SwitchSettingsBox.new(
        _("Dark theme"),
        _("Use a dark theme, if possible"),
        "night-mode",
        on_changed: ->(state) { self.class.apply_dark_theme(state) },
      )
    end

    def clear_database_row
      @clear_database_row ||= ClickableSettingsBox.new(
        _("Clear the database"),
        _("Erase existing accounts"),
        on_activated: ->(_row) { on_clear_database },
      )
    end

    def gpg_location_row
      @gpg_location_row ||= ClickableSettingsBox.new(
        _("GPG keys location"),
        Settings.default.gpg_location,
        on_activated: ->(row) { on_gpg_location(row) },
      )
    end

    def backup_password_row
      @backup_password_row ||= ClickableSettingsBox.new(
        _("Backup Password"),
        "Encrypt the password-protected backups",
        on_activated: ->(_row) { PasswordWindow.new(window).present },
      )
    end

    # Upstream's __on_dark_theme_changed sets GTK's
    # `gtk-application-prefer-dark-theme`; under libadwaita that property is
    # ignored and the style manager's colour scheme is what decides.
    def self.apply_dark_theme(state)
      state.then do |dark|
        if dark
          Adwaita::StyleManager.default.color_scheme = Adwaita::ColorScheme::FORCE_DARK
        else
          Adwaita::StyleManager.default.color_scheme = Adwaita::ColorScheme::DEFAULT
        end
      end
    end

    private

      def on_gpg_location(row)
        FileChoosers.open_directory(window) do |directory|
          Settings.default.gpg_location = directory
          row.secondary_label = directory
        end
      end

      # Upstream's __on_clear_database_clicked: warn, wait five seconds, and
      # clear unless the user hits Undo.
      def on_clear_database
        @clear_cancelled = false
        window.add_toast(clear_toast)
      end

      def clear_toast
        Adwaita::Toast.new(_("The existing accounts will be erased in 5 seconds")).tap do |toast|
          toast.timeout = CLEAR_TIMEOUT
          toast.button_label = _("Undo")
          toast.signal_connect("button-clicked") do
            @clear_cancelled = true
            toast.dismiss
          end
          toast.signal_connect("dismissed") do
            @clear_cancelled.then do |cancelled|
              unless cancelled
                clear_database
              end
            end
          end
        end
      end

      # Upstream's __clear_database: the records, the tokens, the loaded
      # accounts and the widget showing them.
      def clear_database
        Database.default.clear
        Keyring.clear
        AccountsManager.default.clear
        @on_cleared&.call
      end
  end
end
