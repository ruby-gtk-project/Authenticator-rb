# frozen_string_literal: true

require "adwaita"

require_relative "about_dialog"
require_relative "accounts_manager"
require_relative "backup"
require_relative "clipboard"
require_relative "file_choosers"
require_relative "logger"
require_relative "primary_menu"
require_relative "provider_image"
require_relative "settings"
require_relative "settings_window"
require_relative "window"

module Authenticator
  # Application is the application object: it registers the actions the
  # primary menu drives, loads the stylesheet, applies the saved theme, and
  # opens the window.
  #
  # Ported from Authenticator/application.py. Upstream loads its CSS and its
  # icons out of a GResource bundle compiled at build time; the port reads the
  # same two from data/ in the checkout, so the app runs from a clone without
  # a build step.
  #
  # The `import_pgp_json` and `export_pgp_json` actions are not registered:
  # they need the GPG model, which is not ported yet. Registering them with
  # nothing behind them would put two live entries in the menu that do
  # nothing, so they arrive together with the model.
  class Application
    APP_ID = "com.github.bilelmoussaoui.Authenticator"

    # Where the vendored stylesheet lives, relative to this file.
    STYLE_PATH = File.expand_path("../data/style.css", __dir__)

    # Upstream's __setup_actions, minus the two OpenPGP entries.
    ACTIONS = %w[about quit settings import_json export_json].freeze

    def build
      app.tap do |a|
        a.signal_connect("startup") do
          setup_actions
          setup_css
          ProviderImage.register_search_path
          SettingsWindow.apply_dark_theme(Settings.default.night_mode?)
        end

        a.signal_connect("activate") do
          main_window.tap do |win|
            win.build
            win.menu = primary_menu.build
            win.present
          end
        end
      end
    end

    def run(argv = []) = app.run(argv)

    # Adwaita::Application is unusable in the Ruby bindings, so the
    # application object is a Gtk one and only the window is Adwaita. The
    # Adwaita runtime still has to be initialised by hand, which
    # Adwaita.init does.
    def app
      @app ||= Gtk::Application.new(APP_ID, :default_flags).tap do
        Adwaita.init
        GLib.application_name = "Authenticator"
        GLib.prgname = "Authenticator"
      end
    end

    def main_window = @main_window ||= Window.new(app)
    def primary_menu = @primary_menu ||= PrimaryMenu.new
    def about_dialog = @about_dialog ||= AboutDialog.new

    def style_provider
      @style_provider ||= Gtk::CssProvider.new.tap do |provider|
        provider.load_from_path(STYLE_PATH)
      end
    end

    private

      def setup_actions
        ACTIONS.each do |name|
          Gio::SimpleAction.new(name).tap do |action|
            action.signal_connect("activate") { send(:"on_#{name}") }
            app.add_action(action)
          end
        end
      end

      def setup_css
        Gdk::Display.default.then do |display|
          if display
            Gtk::StyleContext.add_provider_for_display(
              display,
              style_provider,
              Gtk::StyleProvider::PRIORITY_USER,
            )
            Logger.debug("Loading CSS")
          end
        end
      end

      def on_about
        about_dialog.present(main_window.window)
      end

      def on_settings
        main_window.show_settings
      end

      # Upstream's __on_quit: clear the clipboard so a code does not outlive
      # the app, stop the countdown, close the window.
      def on_quit
        Clipboard.clear
        AccountsManager.default.kill
        main_window.window.close
        app.quit
      end

      def on_import_json
        FileChoosers.import_json(main_window.window) do |filename|
          BackupJson.import_file(filename) { |account| main_window.on_account_added(account) }
          main_window.update_view
        end
      end

      def on_export_json
        FileChoosers.export_json(main_window.window) do |filename|
          BackupJson.export_file(filename)
        end
      end
  end
end
