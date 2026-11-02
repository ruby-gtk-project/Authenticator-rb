# frozen_string_literal: true

require "adwaita"

module Authenticator
  # SettingsBoxWithEntry is a settings row carrying a text or password field.
  #
  # Ported from the SettingsBoxWithEntry class of
  # Authenticator/widgets/settings.py: a label on the left and a
  # Gtk::Entry — with `visibility` off when it holds a password — on the right.
  # Adwaita::EntryRow and its password variant are that row as one widget, so
  # upstream's `.entry` accessor becomes the text accessors below.
  class SettingsBoxWithEntry
    def initialize(label, password: false, on_changed: nil)
      @label = label
      @password = password
      @on_changed = on_changed
    end

    def build
      @build ||= entry_row.tap do |row|
        row.signal_connect("changed") { @on_changed&.call(row.text) }
      end
    end

    def text = entry_row.text

    def text=(text)
      entry_row.text = text.to_s
    end

    # Marks the field as holding something invalid, which is what upstream's
    # `error` style class on the entry does.
    def error=(error)
      error.then do |invalid|
        if invalid
          entry_row.add_css_class("error")
        else
          entry_row.remove_css_class("error")
        end
      end
    end

    def entry_row
      @entry_row ||= build_row.tap do |row|
        row.title = @label
      end
    end

    private

      def build_row
        @password.then do |password|
          if password
            Adwaita::PasswordEntryRow.new
          else
            Adwaita::EntryRow.new
          end
        end
      end
  end
end
