# frozen_string_literal: true

require "adwaita"
require "gettext"

require_relative "account"
require_relative "account_config"
require_relative "accounts_manager"

module Authenticator
  # AddAccountWindow is the window the Add button opens: the account form,
  # a Close button and an Add button that stays insensitive until the form
  # validates.
  #
  # Ported from the AddAccountWindow class of
  # Authenticator/widgets/accounts/add.py. Upstream adds the created account to
  # the AccountsManager singleton and then to the AccountsWidget singleton; the
  # port hands it to the `on_added` callback and lets the window that opened
  # this one place it, so the dialog does not reach across the app.
  #
  # Upstream's QR-scan button, and the Ctrl+Q accelerator that triggers it,
  # are both here. The button only goes into the header bar when there is
  # something to scan with — a shell that can select an area and a decoder to
  # read the image — which is upstream's `USE_QRSCANNER and
  # can_use_qrscanner()` test asked of the things that have to work.
  class AddAccountWindow
    include GetText

    def initialize(parent, on_added: nil)
      @parent = parent
      @on_added = on_added
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
            bar.pack_end(add_button)

            close_button.tap do |btn|
              btn.signal_connect("clicked") { win.close }
            end

            add_button.tap do |btn|
              btn.signal_connect("clicked") { on_add }
            end

            AccountConfig.can_scan?.then do |scannable|
              if scannable
                bar.pack_end(scan_button)

                scan_button.tap do |btn|
                  btn.signal_connect("clicked") { on_scan }
                end
              end
            end
          end
        end

        key_controller.tap do |controller|
          controller.signal_connect("key-pressed") do |_, keyval, _, state|
            on_key_pressed(keyval, state)
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
        win.title = _("Add a new account")
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

    def close_button = @close_button ||= Gtk::Button.new(label: _("Close"))

    # Upstream's scan_btn, a HeaderBarButton over the `qrscanner-symbolic`
    # icon the vendored theme ships.
    def scan_button
      @scan_button ||= Gtk::Button.new.tap do |btn|
        btn.icon_name = "qrscanner-symbolic"
        btn.tooltip_text = _("Scan QR code")
      end
    end

    def add_button
      @add_button ||= Gtk::Button.new(label: _("Add")).tap do |btn|
        btn.sensitive = false
        btn.add_css_class("suggested-action")
      end
    end

    def account_config
      @account_config ||= AccountConfig.new(
        on_changed: ->(valid) { add_button.sensitive = valid },
      )
    end

    def key_controller = @key_controller ||= Gtk::EventControllerKey.new

    private

      # Upstream's _on_add: create the account, register it, show it, close.
      def on_add
        account_config.account.then do |values|
          Account.create(values["username"], values["provider"], values["token"]).then do |account|
            if account
              AccountsManager.default.add(account)
              @on_added&.call(account)
              window.close
            end
          end
        end
      end

      # Upstream's _on_scan, which the button and the accelerator share.
      def on_scan
        account_config.scan_qr
      end

      # Upstream's _on_key_press: Escape closes the window and Ctrl+Q starts a
      # scan. Upstream tests the modifier state for CONTROL_MASK | MOD2_MASK,
      # which only matches while Num Lock happens to be on; GTK 4 hands the
      # controller the modifiers directly, so asking for the control bit is
      # both the intent and reliable.
      def on_key_pressed(keyval, state)
        (keyval == Gdk::Keyval::KEY_Escape).then do |escape|
          if escape
            window.close
          end
          scan_requested?(keyval, state).then do |scan|
            if scan
              on_scan
            end
            escape || scan
          end
        end
      end

      # The modifier state arrives as a Gdk::ModifierType from the controller,
      # but the bindings hand plain integers through in some places, so the
      # control bit is tested numerically and both read the same.
      def scan_requested?(keyval, state)
        keyval == Gdk::Keyval::KEY_q &&
          !(state.to_i & Gdk::ModifierType::CONTROL_MASK.to_i).zero?
      end
  end
end
