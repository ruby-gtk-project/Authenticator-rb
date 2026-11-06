# frozen_string_literal: true

require "adwaita"
require "gettext"

module Authenticator
  # PrimaryMenu is the model behind the header bar's hamburger button.
  #
  # Ported from the __generate_menu method of Authenticator/application.py: a
  # backup section carrying a Restore and a Backup submenu, then a section with
  # Settings, About and Quit.
  #
  # Upstream's submenus each list two formats, plain-text JSON and
  # OpenPGP-encrypted JSON, in that order.
  class PrimaryMenu
    include GetText

    def build
      @build ||= menu.tap do |root|
        root.append_section(nil, backup_content)
        root.append_section(nil, main_content)

        backup_content.tap do |backup|
          backup.append_submenu(_("Restore"), import_menu)
          backup.append_submenu(_("Backup"), export_menu)

          import_menu.tap do |import|
            import.append(_("from a plain-text JSON file"), "app.import_json")
            import.append(_("from an OpenPGP-encrypted JSON file"), "app.import_pgp_json")
          end

          export_menu.tap do |export|
            export.append(_("in a plain-text JSON file"), "app.export_json")
            export.append(_("in an OpenPGP-encrypted JSON file"), "app.export_pgp_json")
          end
        end

        main_content.tap do |main|
          main.append(_("Settings"), "app.settings")
          main.append(_("About"), "app.about")
          main.append(_("Quit"), "app.quit")
        end
      end
    end

    def menu = @menu ||= Gio::Menu.new
    def backup_content = @backup_content ||= Gio::Menu.new
    def import_menu = @import_menu ||= Gio::Menu.new
    def export_menu = @export_menu ||= Gio::Menu.new
    def main_content = @main_content ||= Gio::Menu.new
  end
end
