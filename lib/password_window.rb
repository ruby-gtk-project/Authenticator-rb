# frozen_string_literal: true

require "adwaita"

require_relative "settings"
require_relative "settings_box_with_entry"

module Authenticator
  # PasswordWindow sets the backup password: the old one when there is one,
  # then the new one twice, behind a Save button that only lights up once all
  # three agree.
  #
  # Ported from the PasswordWindow class of
  # Authenticator/widgets/settings.py. Upstream never instantiates it — the
  # settings window has no row that opens it — so it is dead code there and the
  # `backup-password` key it reads is missing from upstream's GSettings schema
  # entirely. The port wires it to a row on the settings window's Backup page
  # and declares the key in Settings, which is what makes it reachable.
  class PasswordWindow
    def initialize(parent, on_saved: nil)
      @parent = parent
      @on_saved = on_saved
    end

    def build
      @build ||= window.tap do |win|
        win.transient_for = @parent
        win.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = preferences_page

          header_bar.tap do |bar|
            bar.pack_end(apply_button)

            apply_button.tap do |btn|
              btn.signal_connect("clicked") { on_apply }
            end
          end

          preferences_page.tap do |page|
            page.add(password_group)

            password_group.tap do |group|
              old_password_required?.then do |required|
                if required
                  group.add(old_password_row.build)
                end
              end
              group.add(password_row.build)
              group.add(repeat_password_row.build)
            end
          end
        end
      end
    end

    def present
      build.present
    end

    def window
      @window ||= Adwaita::Window.new.tap do |win|
        win.title = "Backup Password"
        win.modal = true
        win.resizable = false
        win.set_default_size(500, 400)
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def preferences_page = @preferences_page ||= Adwaita::PreferencesPage.new

    def password_group
      @password_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Backup Password"
      end
    end

    def apply_button
      @apply_button ||= Gtk::Button.new(label: "Save").tap do |btn|
        btn.sensitive = false
        btn.add_css_class("suggested-action")
      end
    end

    def old_password_row
      @old_password_row ||= SettingsBoxWithEntry.new(
        "Old Password",
        password:   true,
        on_changed: ->(_text) { validate },
      )
    end

    def password_row
      @password_row ||= SettingsBoxWithEntry.new(
        "Password",
        password:   true,
        on_changed: ->(_text) { validate },
      )
    end

    def repeat_password_row
      @repeat_password_row ||= SettingsBoxWithEntry.new(
        "Repeat Password",
        password:   true,
        on_changed: ->(_text) { validate },
      )
    end

    private

      # Upstream only asks for the old password when one is already set.
      def old_password_required? = !Settings.default.backup_password.empty?

      # Upstream's _validate: a non-empty password, a repeat that matches, and
      # — when one is set — the old password typed back correctly.
      def validate
        [
          mark(password_row, !password_row.text.empty?),
          mark(repeat_password_row, !repeat_password_row.text.empty? && repeat_password_row.text == password_row.text),
          valid_old_password?,
        ].all?.then do |valid|
          apply_button.sensitive = valid
        end
      end

      def valid_old_password?
        old_password_required?.then do |required|
          if required
            mark(old_password_row, old_password_row.text == Settings.default.backup_password)
          else
            true
          end
        end
      end

      def mark(row, valid)
        row.error = !valid
        valid
      end

      def on_apply
        apply_button.sensitive?.then do |sensitive|
          if sensitive
            Settings.default.backup_password = password_row.text
            @on_saved&.call
            window.close
          end
        end
      end
  end
end
