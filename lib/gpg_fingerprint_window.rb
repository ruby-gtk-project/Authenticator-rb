# frozen_string_literal: true

require "adwaita"

require_relative "clickable_settings_box"
require_relative "gpg"

module Authenticator
  # GpgFingerprintWindow lists the OpenPGP keys in the user's keyring so one
  # can be picked to encrypt a backup to.
  #
  # Ported from the FingprintPGPWindow class of
  # Authenticator/widgets/backup/gnupg.py — upstream's spelling of the class,
  # kept here only in the comment. Upstream shows a "Public keys" label
  # followed by one clickable row per public key, then the same for the
  # private keys, and emits a `selected(str)` signal carrying the fingerprint
  # of whichever row was clicked before destroying itself.
  #
  # The signal is the `on_selected` callback: nothing passes this window
  # through a GObject property, so registering a type for one signal would buy
  # nothing. Upstream's two labels-plus-rows sections are two
  # Adwaita::PreferencesGroups, which is that arrangement as one widget each.
  #
  # Upstream's rows catch `button-press-event`, which only a pointer can
  # raise. ClickableSettingsBox listens for Adwaita::ActionRow's `activated`
  # instead, so the keyboard reaches the keys too.
  class GpgFingerprintWindow
    def initialize(parent, on_selected: nil)
      @parent = parent
      @on_selected = on_selected
    end

    def build
      @build ||= window.tap do |win|
        win.transient_for = @parent
        win.content = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = page

          page.tap do |p|
            p.add(public_group)
            p.add(private_group)

            public_group.tap do |group|
              key_rows("public").each { |row| group.add(row.build) }
            end

            private_group.tap do |group|
              key_rows("private").each { |row| group.add(row.build) }
            end
          end
        end
      end
    end

    def present
      build.present
    end

    def window
      @window ||= Adwaita::Window.new.tap do |win|
        win.title = "GPG fingerprint"
        win.modal = true
        win.set_default_size(600, 600)
      end
    end

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def page = @page ||= Adwaita::PreferencesPage.new

    def public_group
      @public_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Public keys"
      end
    end

    def private_group
      @private_group ||= Adwaita::PreferencesGroup.new.tap do |group|
        group.title = "Private keys"
      end
    end

    # The keys in the keyring, as the hash Gpg#keys produces: the public ones
    # under "public" and the secret ones under "private".
    def keys = @keys ||= Gpg.default.keys

    # Upstream's __add_keys, as the rows of one section: the key's first user
    # id as the title and its fingerprint underneath, which is what the click
    # hands back.
    def key_rows(kind)
      @key_rows ||= {}
      @key_rows[kind] ||= keys.fetch(kind, []).map do |key|
        ClickableSettingsBox.new(
          key.fetch("uids", []).first.to_s,
          key.fetch("fingerprint", "").to_s,
          on_activated: ->(_row) { select(key.fetch("fingerprint", "").to_s) },
        )
      end
    end

    private

      # Upstream's __finger_print_selected: emit and go.
      def select(fingerprint)
        @on_selected&.call(fingerprint)
        window.close
      end
  end
end
