# frozen_string_literal: true

require "adwaita"

module Authenticator
  # HeaderBar is the window's title bar, and the state machine behind which of
  # its buttons are showing.
  #
  # Ported from Authenticator/widgets/headerbar.py, which is also where
  # upstream's HeaderBarBtn, HeaderBarButton and HeaderBarToggleButton live —
  # three classes whose whole job is to put a themed icon and a tooltip on a
  # button, which GTK 4 does from the constructor.
  #
  # The three states are upstream's HeaderBarState:
  #
  #   EMPTY   no accounts yet: Add and the menu, nothing to search or select
  #   NORMAL  everything
  #   SELECT  selection mode: Cancel, a prompt for a title, no close buttons
  #
  # Upstream's hide_()/show_() pair sets `visible` and GTK 3's `no_show_all`
  # together, because `show_all` would otherwise bring a hidden widget back;
  # GTK 4 dropped `show_all`, so `visible` alone is the whole story.
  class HeaderBar
    EMPTY = :empty
    NORMAL = :normal
    SELECT = :select

    attr_reader :state

    def initialize(on_add: nil, on_toggle_select: nil)
      @on_add = on_add
      @on_toggle_select = on_toggle_select
      @state = NORMAL
    end

    def build
      @build ||= header_bar.tap do |bar|
        bar.pack_start(add_button)
        bar.pack_start(cancel_button)
        bar.pack_end(menu_button)
        bar.pack_end(select_button)
        bar.pack_end(search_button)

        add_button.tap do |btn|
          btn.signal_connect("clicked") { @on_add&.call }
        end

        select_button.tap do |btn|
          btn.signal_connect("clicked") { @on_toggle_select&.call }
        end

        cancel_button.tap do |btn|
          btn.signal_connect("clicked") { @on_toggle_select&.call }
        end
      end
    end

    # Upstream's generate_popover_menu: the menu model behind the hamburger.
    def menu=(menu_model)
      menu_button.menu_model = menu_model
    end

    # Upstream's set_state, state by state.
    def state=(state)
      leave_select_mode
      case state
      when EMPTY then apply_empty_state
      when SELECT then apply_select_state
      else apply_normal_state
      end
      @state = state
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def add_button
      @add_button ||= Gtk::Button.new(icon_name: "list-add-symbolic").tap do |btn|
        btn.tooltip_text = "Add a new account"
      end
    end

    def search_button
      @search_button ||= Gtk::ToggleButton.new.tap do |btn|
        btn.icon_name = "system-search-symbolic"
        btn.tooltip_text = "Search"
      end
    end

    def select_button
      @select_button ||= Gtk::Button.new(icon_name: "object-select-symbolic").tap do |btn|
        btn.tooltip_text = "Selection mode"
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |btn|
        btn.icon_name = "open-menu-symbolic"
        btn.tooltip_text = "Settings"
      end
    end

    def cancel_button
      @cancel_button ||= Gtk::Button.new(label: "Cancel").tap do |btn|
        btn.visible = false
      end
    end

    def select_title
      @select_title ||= Adwaita::WindowTitle.new("Click on items to select them", "")
    end

    private

      # Everything the SELECT state turned on, turned off again — upstream
      # does this by checking the *previous* state at the end of set_state.
      def leave_select_mode
        (@state == SELECT).then do |was_selecting|
          if was_selecting
            header_bar.remove_css_class("selection-mode")
            header_bar.show_end_title_buttons = true
            header_bar.title_widget = nil
          end
        end
        cancel_button.visible = false
      end

      def apply_empty_state
        add_button.visible = true
        search_button.visible = false
        select_button.visible = false
        menu_button.visible = true
      end

      def apply_select_state
        search_button.visible = true
        add_button.visible = false
        select_button.visible = false
        menu_button.visible = false
        cancel_button.visible = true
        header_bar.show_end_title_buttons = false
        header_bar.add_css_class("selection-mode")
        header_bar.title_widget = select_title
      end

      def apply_normal_state
        search_button.visible = true
        add_button.visible = true
        select_button.visible = true
        menu_button.visible = true
      end
  end
end
