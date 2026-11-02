# frozen_string_literal: true

require "adwaita"

require_relative "account_config"

module Authenticator
  # EditAccountWindow is the window the row's Edit button opens: the same
  # account form, pre-filled and without the token field, behind a Save
  # button.
  #
  # Ported from Authenticator/widgets/accounts/edit.py. Upstream's
  # `updated(str, str)` signal is the `on_updated` callback, and its reach into
  # the AccountsWidget singleton to move the account between provider groups is
  # the `on_provider_changed` callback — the window that opened this one knows
  # the widget, so it does the moving.
  class EditAccountWindow
    def initialize(parent, account, on_updated: nil, on_provider_changed: nil)
      @parent = parent
      @account = account
      @on_updated = on_updated
      @on_provider_changed = on_provider_changed
    end

    def build
      @build ||= window.tap do |win|
        win.transient_for = @parent
        win.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = account_config.build

          header_bar.tap do |bar|
            bar.pack_start(close_button)
            bar.pack_end(save_button)

            close_button.tap do |btn|
              btn.signal_connect("clicked") { win.close }
            end

            save_button.tap do |btn|
              btn.signal_connect("clicked") { on_save }
            end
          end
        end

        key_controller.tap do |controller|
          controller.signal_connect("key-pressed") do |_, keyval, _, _|
            on_key_pressed(keyval)
          end
        end
        win.add_controller(key_controller)
      end
    end

    def present
      build.present
    end

    def window
      @window ||= Adwaita::Window.new.tap do |win|
        win.title = "Edit #{@account.username} - #{@account.provider}"
        win.modal = true
        win.set_default_size(400, 600)
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_end_title_buttons = false
      end
    end

    def close_button = @close_button ||= Gtk::Button.new(label: "Close")

    def save_button
      @save_button ||= Gtk::Button.new(label: "Save").tap do |btn|
        btn.add_css_class("suggested-action")
      end
    end

    def account_config
      @account_config ||= AccountConfig.new(
        edit:       true,
        account:    @account,
        on_changed: ->(valid) { save_button.sensitive = valid },
      )
    end

    def key_controller = @key_controller ||= Gtk::EventControllerKey.new

    private

      # Upstream's _on_save: tell the row about the new username and provider,
      # move the account between provider groups if the provider changed, and
      # close.
      def on_save
        @account.provider.then do |old_provider|
          account_config.account.then do |values|
            @on_updated&.call(values["username"], values["provider"])
            (values["provider"] != old_provider).then do |moved|
              if moved
                @on_provider_changed&.call(@account, values["provider"])
              end
            end
          end
        end
        window.close
      end

      def on_key_pressed(keyval)
        (keyval == Gdk::Keyval::KEY_Escape).then do |escape|
          if escape
            window.close
          end
          escape
        end
      end
  end
end
