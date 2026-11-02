# frozen_string_literal: true

require "adwaita"

module Authenticator
  # PrimaryMenu is the model behind the header bar's hamburger button.
  #
  # Ported from the __generate_menu method of Authenticator/application.py: a
  # backup section carrying a Restore and a Backup submenu, then a section with
  # Settings, About and Quit.
  #
  # Upstream's submenus each list two formats, plain-text JSON and
  # OpenPGP-encrypted JSON. The OpenPGP entries are not here because the GPG
  # model they drive is not ported yet — a menu item that activates an action
  # nobody registered is a dead entry in the menu, so the entries arrive with
  # the model.
  class PrimaryMenu
    def build
      @build ||= menu.tap do |root|
        root.append_section(nil, backup_content)
        root.append_section(nil, main_content)

        backup_content.tap do |backup|
          backup.append_submenu("Restore", import_menu)
          backup.append_submenu("Backup", export_menu)

          import_menu.tap do |import|
            import.append("from a plain-text JSON file", "app.import_json")
          end

          export_menu.tap do |export|
            export.append("in a plain-text JSON file", "app.export_json")
          end
        end

        main_content.tap do |main|
          main.append("Settings", "app.settings")
          main.append("About", "app.about")
          main.append("Quit", "app.quit")
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
