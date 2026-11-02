# frozen_string_literal: true

require "adwaita"

require_relative "logger"

module Authenticator
  # FileChoosers opens the file dialogs the backup actions need.
  #
  # Ported from Authenticator/widgets/utils.py, which offers four wrappers
  # over one Gtk::FileChooserNative — import/export of plain JSON and of
  # OpenPGP-encrypted JSON — plus a folder picker for the GPG keys location.
  #
  # Upstream runs each chooser synchronously and returns the chosen filename,
  # which GTK 4 does not allow: Gtk::FileDialog is asynchronous, so every
  # method here takes the block that upstream would have run after the return
  # instead, and calls it with the chosen path. A dismissed dialog calls
  # nothing, which is upstream's `return None`.
  class FileChoosers
    JSON_MIME = "application/json"
    PGP_MIME = "application/pgp-encrypted"

    class << self
      def import_json(parent, &on_chosen)
        open(
          parent,
          JSON_MIME,
          "JSON files",
          &on_chosen
        )
      end

      def export_json(parent, &on_chosen)
        save(
          parent,
          JSON_MIME,
          "JSON files",
          "authenticator.json",
          &on_chosen
        )
      end

      def import_pgp_json(parent, &on_chosen)
        open(
          parent,
          PGP_MIME,
          "Encrypted GPG files",
          &on_chosen
        )
      end

      def export_pgp_json(parent, &on_chosen)
        save(
          parent,
          PGP_MIME,
          "Encrypted GPG files",
          "authenticator.json.asc",
          &on_chosen
        )
      end

      # Upstream's open_directory, used to pick the GPG keys location.
      def open_directory(parent, &on_chosen)
        Gtk::FileDialog.new.tap do |dialog|
          dialog.modal = true
          dialog.select_folder(parent) do |_source, result|
            finish(on_chosen) { dialog.select_folder_finish(result) }
          end
        end
      end

      private

        def open(parent, mime, name, &on_chosen)
          Gtk::FileDialog.new.tap do |dialog|
            dialog.modal = true
            dialog.default_filter = filter(mime, name)
            dialog.open(parent) do |_source, result|
              finish(on_chosen) { dialog.open_finish(result) }
            end
          end
        end

        def save(parent, mime, name, initial_name, &on_chosen)
          Gtk::FileDialog.new.tap do |dialog|
            dialog.modal = true
            dialog.default_filter = filter(mime, name)
            dialog.initial_name = initial_name
            dialog.save(parent) do |_source, result|
              finish(on_chosen) { dialog.save_finish(result) }
            end
          end
        end

        def filter(mime, name)
          Gtk::FileFilter.new.tap do |f|
            f.name = name
            f.add_mime_type(mime)
          end
        end

        # A dismissed dialog raises out of its _finish call rather than
        # handing back nil, so that is where "the user said no" is absorbed.
        def finish(on_chosen)
          yield.then do |file|
            if file&.path
              on_chosen&.call(file.path)
            end
          end
        rescue GLib::Error => e
          Logger.debug("[FileChooser] dismissed: #{e.message}")
        end
    end
  end
end
