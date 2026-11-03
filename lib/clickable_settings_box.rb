# frozen_string_literal: true

require "adwaita"

module Authenticator
  # ClickableSettingsBox is a settings row that does something when clicked.
  #
  # Ported from the ClickableSettingsBox class of
  # Authenticator/widgets/settings.py, which wraps a label and a sub-label in a
  # Gtk::EventBox so it can catch `button-press-event`. GTK 4 removed
  # Gtk::EventBox, and Adwaita::ActionRow is activatable in its own right, so
  # the row's `activated` signal is what upstream's button press was — and
  # unlike a button press it also fires from the keyboard.
  #
  # Adwaita::PreferencesRow parses its title as Pango markup by default, which
  # upstream's plain Gtk::Label does not. A GPG user id contains its owner's
  # address in angle brackets, so left on, markup turns one of those titles
  # into a parse error and an empty row; `use_markup` off is what keeps every
  # title literal.
  class ClickableSettingsBox
    def initialize(label, sub_label = nil, on_activated: nil)
      @label = label
      @sub_label = sub_label
      @on_activated = on_activated
    end

    def build
      @build ||= action_row.tap do |row|
        row.signal_connect("activated") { @on_activated&.call(self) }
      end
    end

    # Upstream's secondary_lbl, which the GPG location row rewrites once the
    # user has picked a directory.
    def secondary_label=(text)
      action_row.subtitle = text.to_s
    end

    def action_row
      @action_row ||= Adwaita::ActionRow.new.tap do |row|
        row.use_markup = false
        row.title = @label
        row.subtitle = @sub_label.to_s
        row.subtitle_selectable = true
        row.activatable = true
      end
    end
  end
end
