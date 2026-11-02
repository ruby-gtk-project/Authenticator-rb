# frozen_string_literal: true

require "adwaita"

module Authenticator
  # ActionsBar is the bar that appears under the accounts list in selection
  # mode, carrying the Delete button.
  #
  # Ported from Authenticator/widgets/actions_bar.py. Upstream is a
  # Gtk::ActionBar singleton kept hidden with the GTK 3 `no_show_all` trick;
  # GTK 4 dropped `show_all` and with it `no_show_all`, so hiding is just
  # `visible = false`.
  class ActionsBar
    def initialize(on_delete: nil)
      @on_delete = on_delete
    end

    def build
      @build ||= action_bar.tap do |bar|
        bar.pack_end(delete_button)

        delete_button.tap do |btn|
          btn.signal_connect("clicked") { @on_delete&.call }
        end
      end
    end

    # Upstream's on_selected_rows_changed: the Delete button is sensitive only
    # while something is selected.
    def on_selected_rows_changed(selected_rows)
      delete_button.sensitive = selected_rows.positive?
    end

    def visible=(visible)
      action_bar.visible = visible
    end

    def visible? = action_bar.visible?

    def action_bar
      @action_bar ||= Gtk::ActionBar.new.tap do |bar|
        bar.visible = false
      end
    end

    def delete_button
      @delete_button ||= Gtk::Button.new(label: "Delete").tap do |btn|
        btn.sensitive = false
        btn.add_css_class("destructive-action")
      end
    end
  end
end
