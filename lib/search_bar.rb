# frozen_string_literal: true

require "adwaita"

module Authenticator
  # SearchBar is the search field that slides down over the accounts list.
  #
  # Ported from Authenticator/widgets/search_bar.py. Upstream binds its
  # `search-mode-enabled` to the header bar's search toggle, and on every
  # keystroke pushes a filter function plus the typed text into each of the
  # provider lists. GTK 4's filter functions take only the row, so the port
  # hands the query to the lists and lets them invalidate their own filter —
  # see AccountsList#query=.
  #
  # Upstream also forwards every window key press into
  # Gtk::SearchBar#handle_event, which GTK 4 replaced with
  # `key_capture_widget`: the bar watches the window itself.
  class SearchBar
    def initialize(on_query_changed: nil)
      @on_query_changed = on_query_changed
    end

    def build
      @build ||= search_bar.tap do |bar|
        bar.child = search_entry
        bar.connect_entry(search_entry)

        search_entry.tap do |entry|
          entry.signal_connect("search-changed") do
            @on_query_changed&.call(entry.text)
          end
        end
      end
    end

    # Binds the bar's search mode to the header bar's search toggle, in both
    # directions, as upstream's search_button setter does.
    def search_button=(button)
      search_bar.bind_property(
        "search-mode-enabled",
        button,
        "active",
        :bidirectional,
      )
    end

    # The bar watches this widget for the keystrokes that open it.
    def key_capture_widget=(widget)
      search_bar.key_capture_widget = widget
    end

    def search_bar
      @search_bar ||= Gtk::SearchBar.new.tap do |bar|
        bar.show_close_button = true
      end
    end

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.width_chars = 28
      end
    end
  end
end
