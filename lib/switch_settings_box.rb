# frozen_string_literal: true

require "adwaita"

require_relative "settings"

module Authenticator
  # SwitchSettingsBox is a settings row with a switch, backed by one settings
  # key.
  #
  # Ported from the SwitchSettingsBox class of
  # Authenticator/widgets/settings.py: a label and a dimmed sub-label on the
  # left, a switch on the right, and a `changed(bool)` signal — the
  # `on_changed` callback here.
  #
  # Upstream hand-builds the row out of boxes and labels and reads the new
  # value as `not switch.get_state()`, because GTK 3's `state-set` fires before
  # the switch's state has moved. Adwaita::SwitchRow is that layout as one
  # widget, and its `active` notification fires after the move, so the new
  # value is simply what the row says it is.
  class SwitchSettingsBox
    def initialize(label, sub_label, key, on_changed: nil)
      @label = label
      @sub_label = sub_label
      @key = key
      @on_changed = on_changed
    end

    def build
      @build ||= switch_row.tap do |row|
        row.signal_connect("notify::active") do
          Settings.default[@key] = row.active?
          @on_changed&.call(row.active?)
        end
      end
    end

    def active? = switch_row.active?

    def switch_row
      @switch_row ||= Adwaita::SwitchRow.new.tap do |row|
        row.title = @label
        row.subtitle = @sub_label
        row.active = (Settings.default[@key] == true)
      end
    end
  end
end
