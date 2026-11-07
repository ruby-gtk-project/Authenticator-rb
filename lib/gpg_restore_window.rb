# frozen_string_literal: true

require "adwaita"
require "gettext"

require_relative "backup"
require_relative "gpg"
require_relative "settings_box_with_entry"

module Authenticator
  # GpgRestoreWindow asks for the passphrase of an OpenPGP-encrypted backup
  # and imports the accounts inside it.
  #
  # Ported from the GPGRestoreWindow class of
  # Authenticator/widgets/backup/gnupg.py: one password field under a header
  # bar whose only button is a suggested-action Import.
  #
  # Upstream reports a failed decrypt with a Gd::Notification pushed into the
  # window's last child. libgd is gone in GTK 4; an Adwaita toast over the
  # content is the same five-second in-window message, so the toast overlay
  # below is what upstream's notification parent was.
  #
  # Upstream also reaches into the AccountsWidget singleton from the Backup
  # model to place each imported account. The port's Backup takes a block
  # instead, so the accounts land through the `on_imported` callback the window
  # that opened this one passes in.
  class GpgRestoreWindow
    include GetText

    # Upstream's notification timeout, in seconds.
    NOTIFICATION_TIMEOUT = 5

    # What upstream substitutes for an empty passphrase. gpg reads the
    # passphrase off a pipe and an empty line would read as "no passphrase at
    # all", which is a different question from "the passphrase is blank".
    BLANK_PASSPHRASE = " "

    def initialize(parent, filename, on_imported: nil, on_finished: nil)
      @parent = parent
      @filename = filename
      @on_imported = on_imported
      @on_finished = on_finished
    end

    def build
      @build ||= window.tap do |win|
        win.transient_for = @parent
        win.content = toast_overlay

        toast_overlay.tap do |overlay|
          overlay.child = toolbar_view

          toolbar_view.tap do |view|
            view.add_top_bar(header_bar)
            view.content = page

            header_bar.tap do |bar|
              bar.pack_end(import_button)

              import_button.tap do |btn|
                btn.signal_connect("clicked") { on_apply }
              end
            end

            page.tap do |p|
              p.add(group)

              group.tap do |g|
                g.add(paraphrase_widget.build)
              end
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
        win.title = _("GPG paraphrase")
        win.modal = true
        win.set_default_size(400, 200)
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new
    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new
    def header_bar = @header_bar ||= Adwaita::HeaderBar.new
    def page = @page ||= Adwaita::PreferencesPage.new
    def group = @group ||= Adwaita::PreferencesGroup.new

    def import_button
      @import_button ||= Gtk::Button.new(label: _("Import")).tap do |btn|
        btn.add_css_class("suggested-action")
      end
    end

    def paraphrase_widget
      @paraphrase_widget ||= SettingsBoxWithEntry.new(_("Paraphrase"), password: true)
    end

    # Upstream's __send_notification, as an Adwaita toast.
    def notify(message)
      toast_overlay.add_toast(
        Adwaita::Toast.new(message).tap do |toast|
          toast.timeout = NOTIFICATION_TIMEOUT
        end,
      )
    end

    private

      # Upstream's __on_apply: decrypt the file into the cache directory with
      # the typed passphrase, import what came out, and close. A failed
      # decrypt says so and leaves the window open so the passphrase can be
      # corrected.
      def on_apply
        passphrase.then do |secret|
          output_file.then do |target|
            Gpg.default.decrypt_json(@filename, secret, target).then do |status|
              if status.ok
                import(target)
              else
                notify(_("There was an error during the import of the encrypted file."))
              end
            end
          end
        end
      end

      def import(target)
        BackupJson.import_file(target) { |account| @on_imported&.call(account) }
        File.file?(target).then do |written|
          if written
            File.unlink(target)
          end
        end
        @on_finished&.call
        window.close
      end

      def passphrase
        paraphrase_widget.text.then do |typed|
          if typed.empty?
            BLANK_PASSPHRASE
          else
            typed
          end
        end
      end

      # Upstream writes the plaintext to a NamedTemporaryFile's name inside
      # the user's cache directory. It is the whole account store in the
      # clear, so `import` above removes it as soon as it has been read.
      def output_file
        File.join(
          GLib.user_cache_dir,
          "authenticator-restore-#{Process.pid}-#{Time.now.to_i}-#{rand(1 << 24)}.json",
        )
      end
  end
end
