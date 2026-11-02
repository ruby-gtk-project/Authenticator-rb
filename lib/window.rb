# frozen_string_literal: true

require "adwaita"

require_relative "account_row"
require_relative "accounts_manager"
require_relative "accounts_widget"
require_relative "actions_bar"
require_relative "add_account_window"
require_relative "database"
require_relative "edit_account_window"
require_relative "empty_accounts_list"
require_relative "header_bar"
require_relative "logger"
require_relative "provider_image"
require_relative "search_bar"
require_relative "settings"
require_relative "settings_window"

module Authenticator
  # Window is the main window: the header bar over a search bar, a stack that
  # shows either the accounts or the empty state, and the actions bar that
  # selection mode reveals.
  #
  # Ported from Authenticator/widgets/window.py. Upstream is a singleton that
  # every other widget reaches for; the port passes it where it is needed
  # instead, which is what lets the dialogs below be built from here rather
  # than from inside the rows and forms that ask for them.
  #
  # Upstream saves and restores the window's position across runs. GTK 4
  # removed Gtk::Window#move and #get_position outright — placement is the
  # compositor's business now — so only the maximized state can be restored.
  # The `window-position` key stays in Settings because upstream's schema has
  # it, and nothing writes to it any more.
  class Window
    def initialize(app)
      @app = app
    end

    def build
      @build ||= window.tap do |win|
        win.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar.build)
          view.add_top_bar(search_bar.build)
          view.content = main_stack
          view.add_bottom_bar(actions_bar.build)

          search_bar.tap do |bar|
            bar.search_button = header_bar.search_button
            bar.key_capture_widget = win
          end

          main_stack.tap do |stack|
            stack.add_named(accounts_widget.build, "accounts-list")
            stack.add_named(empty_accounts_list.build, "empty-accounts-list")
          end
        end

        win.signal_connect("close-request") do
          save_state
          AccountsManager.default.kill
          false
        end

        update_view
      end
    end

    def present
      build.present
    end

    # Upstream's set_menu: hand the application's menu model to the header bar.
    def menu=(menu_model)
      header_bar.menu = menu_model
    end

    # Upstream's update_view: an empty database shows the empty state and
    # strips the header bar down to Add; anything else shows the list.
    def update_view
      main_stack.get_child_by_name("accounts-list").then do |built|
        if built
          apply_view(Database.default.count.zero?)
        end
      end
    end

    # Upstream's toggle_select: in and out of selection mode, taking the
    # header bar, the lists and the actions bar with it. Upstream keeps the
    # actions bar and the header's Cancel button in step with a bidirectional
    # property binding; one assignment each says the same thing without the
    # binding's surprise direction.
    def toggle_select
      (header_bar.state == HeaderBar::NORMAL).then do |entering|
        if entering
          header_bar.state = HeaderBar::SELECT
          accounts_widget.state = AccountsList::SELECT
          actions_bar.visible = true
        else
          header_bar.state = HeaderBar::NORMAL
          accounts_widget.state = AccountsList::NORMAL
          actions_bar.visible = false
        end
      end
    end

    # Upstream's add_account: open the add window and place whatever it
    # created.
    def add_account
      AddAccountWindow.new(
        window,
        on_added: ->(account) { on_account_added(account) },
      ).present
    end

    def show_settings
      SettingsWindow.new(window, on_cleared: -> { on_database_cleared }).present
    end

    # Puts a freshly imported or created account into the list and refreshes
    # which page the stack is showing.
    def on_account_added(account)
      accounts_widget.append(account)
      update_view
    end

    def on_database_cleared
      accounts_widget.clear
      update_view
    end

    def save_state
      Settings.default.window_maximized = window.maximized?
    end

    def window
      @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
        win.title = "Authenticator"
        win.icon_name = ProviderImage::APP_ICON
        win.set_default_size(550, 600)
        Settings.default.window_maximized?.then do |maximized|
          if maximized
            win.maximize
          end
        end
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def main_stack = @main_stack ||= Gtk::Stack.new
    def empty_accounts_list = @empty_accounts_list ||= EmptyAccountsList.new

    def header_bar
      @header_bar ||= HeaderBar.new(
        on_add:           -> { add_account },
        on_toggle_select: -> { toggle_select },
      )
    end

    def search_bar
      @search_bar ||= SearchBar.new(
        on_query_changed: ->(query) { accounts_widget.query = query },
      )
    end

    def actions_bar
      @actions_bar ||= ActionsBar.new(on_delete: -> { delete_selected })
    end

    def accounts_widget
      @accounts_widget ||= AccountsWidget.new(
        on_changed:               -> { update_view },
        on_selected_rows_changed: ->(count) { actions_bar.on_selected_rows_changed(count) },
        on_edit:                  ->(row) { edit_account(row) },
      )
    end

    private

      def apply_view(empty)
        empty.then do |nothing_stored|
          if nothing_stored
            header_bar.state = HeaderBar::EMPTY
            main_stack.visible_child_name = "empty-accounts-list"
          else
            header_bar.state = HeaderBar::NORMAL
            main_stack.visible_child_name = "accounts-list"
          end
        end
      end

      # Upstream's _on_account_delete: delete, leave selection mode, and
      # re-decide which page the stack shows.
      def delete_selected
        accounts_widget.delete_selected
        toggle_select
        update_view
      end

      def edit_account(row)
        EditAccountWindow.new(
          window,
          row.account,
          on_updated:          ->(username, provider) { row.update(username, provider) },
          on_provider_changed: ->(account, provider) { accounts_widget.update_provider(account, provider) },
        ).present
      end
  end
end
