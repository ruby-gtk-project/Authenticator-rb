# frozen_string_literal: true

require "adwaita"
require "gettext"

module Authenticator
  # AccountRow is one account in the list: its username, its current code, a
  # Copy button, an Edit button, and the check button that selection mode
  # reveals.
  #
  # Ported from Authenticator/widgets/accounts/row.py, which is also where
  # upstream's ActionButton and ActionsBox live — two classes that exist only
  # to give a Gtk::Button an icon and a tooltip, which GTK 4 does from the
  # constructor, so they are the two buttons below instead.
  #
  # Upstream's row opens the edit window itself by reaching for the Window
  # singleton; the port takes an `on_edit` callback, so the row does not need
  # to know what a window is and the window stays the thing that owns dialogs.
  class AccountRow
    include GetText

    attr_reader :account

    def initialize(account, on_selected: nil, on_edit: nil)
      @account = account
      @on_selected = on_selected
      @on_edit = on_edit
    end

    def build
      @build ||= row.tap do |r|
        r.child = container

        container.tap do |box|
          box.append(check_button)
          box.append(info_container)
          box.append(otp_container)
          box.append(actions_container)

          check_button.tap do |btn|
            btn.signal_connect("toggled") { @on_selected&.call }
          end

          info_container.tap do |info|
            info.append(username_label)
          end

          otp_container.tap do |otp|
            otp.append(pin_label)
          end

          actions_container.tap do |actions|
            actions.append(copy_button)
            actions.append(edit_button)

            copy_button.tap do |btn|
              btn.signal_connect("clicked") { @account.copy_pin }
            end

            edit_button.tap do |btn|
              btn.signal_connect("clicked") { @on_edit&.call(self) }
            end
          end
        end

        @account.on_otp_updated { |pin| on_pin_updated(pin) }
      end
    end

    # Whether the check button is ticked — upstream's `checked` property.
    def checked? = check_button.active?

    def checked=(checked)
      check_button.active = checked
    end

    # Selection mode reveals the check buttons; leaving it hides them again
    # and unticks them, so a row cannot stay selected invisibly.
    def selectable=(selectable)
      check_button.visible = selectable
      selectable.then do |showing|
        unless showing
          check_button.active = false
        end
      end
    end

    # Upstream's _on_update: write the new username into the label and the
    # new username and provider into the database.
    def update(username, provider)
      username_label.label = username
      username_label.tooltip_text = username
      @account.update(username, provider)
    end

    def on_pin_updated(pin)
      pin.then do |code|
        if code
          pin_label.label = code
        end
      end
    end

    def row
      @row ||= Gtk::ListBoxRow.new.tap do |r|
        r.activatable = false
        r.add_css_class("account-row")
      end
    end

    def container
      @container ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.margin_start = 3
        box.margin_end = 3
      end
    end

    def check_button
      @check_button ||= Gtk::CheckButton.new.tap do |btn|
        btn.visible = false
        btn.valign = :center
        btn.add_css_class("account-row-checkbtn")
      end
    end

    def info_container
      @info_container ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.valign = :center
        box.hexpand = true
        box.margin_start = 6
        box.margin_end = 6
      end
    end

    def username_label
      @username_label ||= Gtk::Label.new(@account.username).tap do |lbl|
        lbl.tooltip_text = @account.username
        lbl.ellipsize = :end
        lbl.halign = :start
        lbl.add_css_class("username")
      end
    end

    def otp_container
      @otp_container ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.valign = :center
        box.halign = :start
        box.margin_start = 6
        box.margin_end = 6
      end
    end

    # Upstream shows "??????" with an explanatory tooltip when the token could
    # not be decoded, and the code itself otherwise.
    def pin_label
      @pin_label ||= Gtk::Label.new.tap do |lbl|
        lbl.halign = :start
        lbl.add_css_class("token-label")
        @account.pin.then do |pin|
          if pin
            lbl.label = pin
          else
            lbl.label = "??????"
            lbl.tooltip_text = _("Couldn't generate the secret code")
          end
        end
      end
    end

    def actions_container
      @actions_container ||= Gtk::Box.new(:horizontal, 3).tap do |box|
        box.valign = :center
        box.margin_start = 6
        box.margin_end = 6
      end
    end

    def copy_button
      @copy_button ||= Gtk::Button.new(icon_name: "edit-copy-symbolic").tap do |btn|
        btn.tooltip_text = _("Copy")
        btn.add_css_class("flat")
      end
    end

    def edit_button
      @edit_button ||= Gtk::Button.new(icon_name: "document-edit-symbolic").tap do |btn|
        btn.tooltip_text = _("Edit")
        btn.add_css_class("flat")
      end
    end
  end
end
