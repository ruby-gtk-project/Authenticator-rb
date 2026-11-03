# frozen_string_literal: true

require "json"

require "adwaita"

require_relative "logger"
require_relative "otp"
require_relative "provider_image"
require_relative "qr_reader"
require_relative "screenshot"

module Authenticator
  # AccountConfig is the account form shared by the add and edit windows: a
  # provider logo above a provider field, an account name and — when adding —
  # the secret token.
  #
  # Ported from the AccountConfig class of
  # Authenticator/widgets/accounts/add.py. Upstream's `changed(bool)` signal,
  # which drives the window's Add/Save button, is the `on_changed` callback.
  #
  # Upstream's provider field is a Gtk::ComboBox.new_with_model_and_entry over
  # the 500-odd providers in data/data.json, with an EntryCompletion on its
  # entry. GTK 4 deprecated Gtk::ComboBox, and the dropdown was never the
  # point — the field has to accept a provider that is not in the list at all,
  # which is why upstream reads the typed text rather than the selection. So
  # the port keeps the completion and drops the dropdown: the same list, the
  # same free-form text, one widget instead of two.
  #
  # `scan_qr` is upstream's: drag out the QR code on screen, read the token
  # out of it and type it into the token field. Upstream reports a bad scan
  # with a Gd::Notification pushed into this box; libgd is gone in GTK 4, so
  # the box sits inside an Adwaita::ToastOverlay and the same message arrives
  # as a toast.
  class AccountConfig
    # Where the vendored provider list lives, relative to this file.
    DATA_PATH = File.expand_path("../data/data.json", __dir__)

    # Column indices of the completion's model.
    NAME_COLUMN = 0
    LOGO_COLUMN = 1

    # Upstream's notification timeout, in seconds.
    NOTIFICATION_TIMEOUT = 5

    def initialize(edit: false, account: nil, on_changed: nil)
      @edit = edit
      @account = account
      @on_changed = on_changed
    end

    def build
      @build ||= toast_overlay.tap do |overlay|
        overlay.child = container

        container.tap do |box|
          box.append(clamp)

          clamp.tap do |c|
            c.child = form

            form.tap do |f|
              f.append(logo_image)
              f.append(provider_entry)
              f.append(username_entry)

              provider_entry.tap do |entry|
                entry.completion = provider_completion
                entry.signal_connect("changed") { on_provider_changed }
              end

              username_entry.tap do |entry|
                entry.signal_connect("changed") { validate }
              end

              @edit.then do |editing|
                unless editing
                  f.append(token_entry)

                  token_entry.tap do |entry|
                    entry.signal_connect("changed") { validate }
                  end
                end
              end
            end
          end

          validate
        end
      end
    end

    # Upstream's scan_qr: let the user drag a rectangle round the QR code,
    # read it, and fill the token field in with what was in it. A cancelled
    # drag does nothing, as upstream's does; a code that is not a usable
    # token says so and leaves the field alone.
    def scan_qr
      Screenshot.area.then do |filename|
        if filename
          QrReader.new(filename).then do |reader|
            read_scan(reader, reader.read)
          end
        end
      end
    end

    # Whether there is anything to scan with: both a shell that can select an
    # area and a decoder to read the image. Upstream asks the same question as
    # `Application.USE_QRSCANNER and can_use_qrscanner()`, the second half of
    # which is a plain check that the desktop is GNOME; asking the session bus
    # whether the screenshot interface is actually there is the same question
    # answered by the thing that has to work.
    def self.can_scan? = QrReader.available? && Screenshot.available?

    # Upstream's __send_notification, as an Adwaita toast.
    def notify(message)
      toast_overlay.add_toast(
        Adwaita::Toast.new(message).tap do |toast|
          toast.timeout = NOTIFICATION_TIMEOUT
        end,
      )
    end

    # Upstream's `account` property: what the window reads when the user
    # confirms. The token is absent while editing, as upstream's is.
    def account
      { "username" => username_entry.text, "provider" => provider_entry.text }.tap do |values|
        @edit.then do |editing|
          unless editing
            values["token"] = token_entry.text
          end
        end
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def container = @container ||= Gtk::Box.new(:vertical, 0)

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |c|
        c.maximum_size = 400
        c.margin_top = 36
        c.margin_bottom = 36
        c.margin_start = 36
        c.margin_end = 36
      end
    end

    def form = @form ||= Gtk::Box.new(:vertical, 12)

    def logo_image
      @logo_image ||= ProviderImage.image(@account&.provider, 96).tap do |img|
        img.margin_bottom = 12
      end
    end

    def provider_entry
      @provider_entry ||= Gtk::Entry.new.tap do |entry|
        entry.placeholder_text = "Provider"
        entry.text = @account&.provider.to_s
      end
    end

    def username_entry
      @username_entry ||= Gtk::Entry.new.tap do |entry|
        entry.placeholder_text = "Account name"
        entry.text = @account&.username.to_s
      end
    end

    def token_entry
      @token_entry ||= Gtk::Entry.new.tap do |entry|
        entry.placeholder_text = "Secret token"
        entry.visibility = false
      end
    end

    def provider_completion
      @provider_completion ||= Gtk::EntryCompletion.new.tap do |completion|
        completion.model = providers_store
        completion.text_column = NAME_COLUMN
        completion.minimum_key_length = 1
      end
    end

    # The providers from data/data.json, sorted case-insensitively by name as
    # upstream sorts them.
    def providers_store
      @providers_store ||= Gtk::ListStore.new(String, String).tap do |store|
        providers.each do |name, logo|
          store.append.tap do |row|
            row.set_value(NAME_COLUMN, name)
            row.set_value(LOGO_COLUMN, logo)
          end
        end
      end
    end

    # name => icon slug, straight out of the vendored data file.
    def providers
      @providers ||= JSON.parse(File.read(DATA_PATH)).sort_by { |name, _logo| name.downcase }
    rescue Errno::ENOENT, JSON::ParserError => e
      Logger.error("[AccountConfig] Could not read #{DATA_PATH}: #{e.message}")
      []
    end

    private

      # Upstream's scan_qr tail: a readable, valid token goes into the field
      # and a bad one is reported. Upstream reports a missing zbar here too;
      # the port's scan button is absent without one, so there is nothing to
      # press and nothing to report.
      def read_scan(reader, secret)
        reader.valid?.then do |usable|
          if usable
            token_entry.text = secret.to_s
          else
            notify("Invalid QR code")
          end
        end
      end

      # Upstream's _on_provider_changed: the logo follows the provider. When
      # the typed name is one of the known providers it uses that provider's
      # icon slug, and otherwise it slugs the typed text, which is what lets a
      # provider the data file has never heard of still find an icon.
      def on_provider_changed
        providers.assoc(provider_entry.text).then do |known|
          if known
            ProviderImage.apply(logo_image, known[LOGO_COLUMN])
          else
            ProviderImage.apply(logo_image, provider_entry.text)
          end
        end
        validate
      end

      # Upstream's _validate: the name and provider must be non-empty, and —
      # unless editing — the token has to be one a code can be generated from.
      # Each invalid field wears the `error` class while it is wrong.
      def validate
        [
          mark(username_entry, !username_entry.text.strip.empty?),
          mark(provider_entry, !provider_entry.text.strip.empty?),
          valid_token?,
        ].all?.then do |valid|
          @on_changed&.call(valid)
        end
      end

      def valid_token?
        @edit.then do |editing|
          if editing
            true
          else
            mark(token_entry, OTP.valid?(token_entry.text.strip))
          end
        end
      end

      def mark(widget, valid)
        valid.then do |ok|
          if ok
            widget.remove_css_class("error")
          else
            widget.add_css_class("error")
          end
        end
        valid
      end
  end
end
