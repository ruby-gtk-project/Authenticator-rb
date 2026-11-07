# frozen_string_literal: true

# Drives the whole application headlessly against a throwaway store and
# asserts what it sees, so a UI claim can be checked rather than asserted:
#
#   nix develop --command xvfb-run -a ruby test/drive_authenticator.rb
#
# Every account, setting and token this creates lives under a temporary
# XDG_CONFIG_HOME and XDG_DATA_HOME that are removed on the way out, so the
# run never touches the real store.

require "fileutils"
require "json"
require "tmpdir"

ROOT = Dir.mktmpdir("authenticator-drive")
ENV["XDG_CONFIG_HOME"] = File.join(ROOT, "config")
ENV["XDG_DATA_HOME"] = File.join(ROOT, "data")

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "authenticator"
require_relative "support/fake_file_dialog"

FakeFileDialog.install!

CHECKS = []

def check(description, expected, actual)
  CHECKS << [description, expected, actual]
  puts(
    format(
      "%-52s %-28s %s",
      description,
      expected.inspect,
      actual.inspect,
    ),
  )
end

# Keep the port's own logging out of the driver's output.
Authenticator::Logger.default = Authenticator::Logger.new(io: File.open(File::NULL, "w"))

# Three accounts across two providers, with RFC 4648 base32 tokens.
accounts = [
  Authenticator::Account.create("me@example.com", "GitHub", "JBSWY3DPEHPK3PXP"),
  Authenticator::Account.create("other@example.com", "GitHub", "GEZDGNBVGY3TQOJQ"),
  Authenticator::Account.create("work", "Amazon", "KRSXG5CTMVRXEZLU"),
]

check("accounts created", 3, accounts.compact.size)
check("database count", 3, Authenticator::Database.default.count)
check(
  "database order (provider asc, username desc)",
  [%w[Amazon work], ["GitHub", "other@example.com"], ["GitHub", "me@example.com"]],
  Authenticator::Database.default.accounts.map { |row| [row["provider"], row["username"]] },
)
check("every account generated a code", [6, 6, 6], accounts.map { |account| account.pin.length })
check("username search", %w[1], Authenticator::Database.default.search(%w[me]))

# RFC 6238 appendix B, the SHA-1 vectors.
Authenticator::OTP.new("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ", digits: 8).then do |otp|
  check("RFC 6238 vector at T=59", "94287082", otp.at(Time.at(59)))
  check("RFC 6238 vector at T=1111111109", "07081804", otp.at(Time.at(1_111_111_109)))
end
check("an unparseable token is rejected", false, Authenticator::OTP.valid?("not base32!"))

app = Authenticator::Application.new
app.build

app.app.signal_connect("activate") do
  window = app.main_window
  widget = window.accounts_widget

  check("stack shows the accounts", "accounts-list", window.main_stack.visible_child_name)
  check("header bar is in its normal state", :normal, window.header_bar.state)
  check("one group per provider", 2, widget.accounts_lists.size)
  check("rows per group", [1, 2], widget.accounts_lists.map { |list| list.rows.size }.sort)

  shown = -> { widget.accounts_lists.sum { |list| list.rows.count { |row| row.build.child_visible? } } }
  widget.query = "work"
  check("search narrows the list", 1, shown.call)
  widget.query = ""
  check("clearing the search restores it", 3, shown.call)

  window.toggle_select
  check("selection mode moved the header bar", :select, window.header_bar.state)
  check("selection mode revealed the actions bar", true, window.actions_bar.visible?)
  check(
    "selection mode revealed the check buttons",
    [true],
    widget.accounts_lists.flat_map(&:rows).map { |row| row.check_button.visible? }.uniq,
  )
  check("delete is insensitive with nothing ticked", false, window.actions_bar.delete_button.sensitive?)
  widget.accounts_lists.flat_map(&:rows).first.checked = true
  check("delete is sensitive once a row is ticked", true, window.actions_bar.delete_button.sensitive?)

  Authenticator::AccountsManager.default.tick
  check("the countdown ticked", 29, Authenticator::AccountsManager.default.counter)
  check("the progress bar followed it", 0.967, widget.otp_progress_bar.fraction.round(3))
  29.times { Authenticator::AccountsManager.default.tick }
  check("a whole period reset the countdown", 30, Authenticator::AccountsManager.default.counter)
  check(
    "codes survived the regeneration",
    [6],
    widget.accounts_lists.flat_map(&:rows).map { |row| row.pin_label.label.length }.uniq,
  )

  widget.accounts_lists.flat_map(&:rows).first.then do |row|
    copied = []
    Authenticator::Clipboard.define_singleton_method(:set) { |string| copied << string }
    row.copy_button.signal_emit("clicked")
    check("the copy button copied the pin to the clipboard", [row.account.pin], copied)
    Authenticator::Clipboard.singleton_class.send(:remove_method, :set)
  end

  edited_via_button = []
  widget.accounts_lists.flat_map(&:rows).first.then do |row|
    original_on_edit = row.instance_variable_get(:@on_edit)
    row.instance_variable_set(:@on_edit, ->(r) { edited_via_button << r; original_on_edit&.call(r) })
    row.edit_button.signal_emit("clicked")
  end
  check("the edit button fired its callback", 1, edited_via_button.size)

  window.send(:delete_selected)
  check("the ticked account is gone", 2, Authenticator::Database.default.count)
  check("its emptied group went with it", 1, widget.accounts_lists.size)

  widget.accounts_lists.flat_map(&:rows).first.then do |row|
    Authenticator::EditAccountWindow.new(
      window.window,
      row.account,
      on_updated:          ->(username, provider) { row.update(username, provider) },
      on_provider_changed: ->(account, provider) { widget.update_provider(account, provider) },
    ).tap do |editor|
      editor.build
      editor.account_config.provider_entry.text = "Dropbox"
      editor.send(:on_save)
    end
  end
  check("the edited account moved to a new group", 2, widget.accounts_lists.size)
  check(
    "the groups are in alphabetical order on screen",
    %w[Dropbox GitHub],
    widget.accounts_container.then do |box|
      [].tap do |order|
        box.first_child.then do |first|
          first.then do |child|
            while child
              order << widget.provider_widgets.find { |_name, pw| pw.build == child }&.first
              child = child.next_sibling
            end
          end
        end
      end
    end,
  )

  Authenticator::AddAccountWindow.new(
    window.window,
    on_added: ->(account) { window.on_account_added(account) },
  ).tap do |adder|
    adder.build
    check("Add is insensitive on an empty form", false, adder.add_button.sensitive?)
    adder.account_config.provider_entry.text = "Slack"
    adder.account_config.username_entry.text = "slacker"
    adder.account_config.token_entry.text = "MFRGGZDFMZTWQ2LK"
    check("Add is sensitive on a valid form", true, adder.add_button.sensitive?)
    adder.send(:on_add)
  end
  check("the added account is stored", 3, Authenticator::Database.default.count)
  check("it opened a third group", 3, widget.accounts_lists.size)

  Authenticator::SettingsWindow.new(
    window.window,
    on_cleared: -> { window.on_database_cleared },
  ).tap do |settings_window|
    settings_window.build
    check(
      "the settings window has upstream's three pages",
      %w[Appearance Behaviour Backup],
      [
        settings_window.appearance_page.title,
        settings_window.behaviour_page.title,
        settings_window.backup_page.title,
      ],
    )
    settings_window.dark_theme_row.build.active = true
    check("the dark theme switch wrote the setting", true, Authenticator::Settings.default.night_mode?)
    check(
      "and told libadwaita",
      Adwaita::ColorScheme::FORCE_DARK,
      Adwaita::StyleManager.default.color_scheme,
    )
    settings_window.dark_theme_row.build.active = false

    check(
      "the backup page lists the GPG location and backup password rows",
      ["GPG keys location", "Backup Password"],
      [settings_window.gpg_location_row.action_row.title, settings_window.backup_password_row.action_row.title],
    )
    check(
      "the clear-database row is on the behaviour page",
      "Clear the database",
      settings_window.clear_database_row.action_row.title,
    )

    # Fires the row's actual `activated` signal (not a direct call to the
    # backend) so FileChoosers.open_directory, and the row rewriting its own
    # subtitle, both run for real.
    File.join(ROOT, "gpg-keys").then do |chosen_dir|
      FileUtils.mkdir_p(chosen_dir)
      FakeFileDialog.next_path = chosen_dir
      settings_window.gpg_location_row.build.signal_emit("activated")
      check(
        "activating the GPG location row wrote the chosen folder to Settings",
        chosen_dir,
        Authenticator::Settings.default.gpg_location,
      )
      check(
        "and rewrote the row's subtitle",
        chosen_dir,
        settings_window.gpg_location_row.action_row.subtitle,
      )
    end

    Authenticator::PasswordWindow.new(settings_window.window).tap do |password_window|
      password_window.build
      password_window.password_row.text = "correct horse"
      check("Save is insensitive until the repeat matches", false, password_window.apply_button.sensitive?)
      password_window.repeat_password_row.text = "correct horse"
      check("Save is sensitive once it does", true, password_window.apply_button.sensitive?)
      password_window.send(:on_apply)
    end
  end
  check("the backup password was stored", "correct horse", Authenticator::Settings.default.backup_password)

  File.join(ROOT, "backup.json").then do |dump|
    Authenticator::BackupJson.export_file(dump)
    check("the export wrote every account", 3, JSON.parse(File.read(dump)).size)

    Authenticator::Database.default.clear
    Authenticator::Keyring.clear
    Authenticator::AccountsManager.default.clear
    widget.clear
    window.update_view
    check("clearing the store shows the empty state", "empty-accounts-list", window.main_stack.visible_child_name)
    check("and strips the header bar down", :empty, window.header_bar.state)

    Authenticator::BackupJson.import_file(dump) { |account| window.on_account_added(account) }
    check("the import brought them back", 3, Authenticator::Database.default.count)
    check("in their groups", 3, widget.accounts_lists.size)
    check("and the list is showing again", "accounts-list", window.main_stack.visible_child_name)
  end

  check(
    "every menu action is registered",
    [true] * 7,
    Authenticator::Application::ACTIONS.map { |name| !app.app.lookup_action(name).nil? },
  )
  app.app.lookup_action("settings").activate(nil)
  check(
    "the settings action opens the settings window",
    true,
    Gtk::Window.list_toplevels.any? { |toplevel| toplevel.is_a?(Adwaita::PreferencesWindow) },
  )

  app.app.lookup_action("about").activate(nil)
  check(
    "the about action opens an AboutWindow",
    true,
    Gtk::Window.list_toplevels.any? { |toplevel| toplevel.is_a?(Adwaita::AboutWindow) },
  )
  Gtk::Window.list_toplevels.find { |toplevel| toplevel.is_a?(Adwaita::AboutWindow) }.then do |about|
    check("it is titled Authenticator", "Authenticator", about.application_name)
    check("and carries the port's version", Authenticator::Rb::VERSION, about.version)
    about.close
  end

  # Drives each FileChoosers dialog through the real menu action that opens
  # it — app.import_json / app.export_json / app.import_pgp_json /
  # app.export_pgp_json — rather than calling BackupJson/Gpg directly, with
  # only the native portal round trip stood in for by FakeFileDialog.

  File.join(ROOT, "export-via-action.json").then do |path|
    FakeFileDialog.next_path = path
    app.app.lookup_action("export_json").activate(nil)
    check("the export-json dialog used the JSON filter", "JSON files", FakeFileDialog.last_filter_name)
    check("and the chosen-path callback wrote the file", 3, JSON.parse(File.read(path)).size)
  end

  File.join(ROOT, "export-via-action.json").then do |path|
    FakeFileDialog.next_path = path
    app.app.lookup_action("import_json").activate(nil)
    check("the import-json dialog used the JSON filter", "JSON files", FakeFileDialog.last_filter_name)
    check(
      "and the chosen-path callback read the file without duplicating accounts",
      3,
      Authenticator::Database.default.count,
    )
  end

  File.join(ROOT, "export-via-action.json.asc").then do |path|
    FakeFileDialog.next_path = path
    app.app.lookup_action("export_pgp_json").activate(nil)
    check("the export-pgp-json dialog used the GPG filter", "Encrypted GPG files", FakeFileDialog.last_filter_name)
    check(
      "and the chosen-path callback opened the fingerprint window",
      true,
      Gtk::Window.list_toplevels.any? { |toplevel| toplevel.is_a?(Adwaita::Window) && toplevel.title == "GPG fingerprint" },
    )
    Gtk::Window.list_toplevels.select { |toplevel| toplevel.is_a?(Adwaita::Window) && toplevel.title == "GPG fingerprint" }.each(&:close)
  end

  File.join(ROOT, "export-via-action.json.asc").then do |path|
    FakeFileDialog.next_path = path
    app.app.lookup_action("import_pgp_json").activate(nil)
    check("the import-pgp-json dialog used the GPG filter", "Encrypted GPG files", FakeFileDialog.last_filter_name)
    check(
      "and the chosen-path callback opened the GPG restore window",
      true,
      Gtk::Window.list_toplevels.any? { |toplevel| toplevel.is_a?(Adwaita::Window) && toplevel.title == "GPG paraphrase" },
    )
    Gtk::Window.list_toplevels.select { |toplevel| toplevel.is_a?(Adwaita::Window) && toplevel.title == "GPG paraphrase" }.each(&:close)
  end

  @cleared = false
  Authenticator::SettingsWindow.new(window.window, on_cleared: -> { @cleared = true }).tap do |settings_window|
    settings_window.build
    settings_window.send(:clear_database)
  end
  check("clearing the database emptied the store", 0, Authenticator::Database.default.count)
  check("and told its caller", true, @cleared)

  Authenticator::AccountsManager.default.kill
  app.app.quit
end

app.run([])
FileUtils.remove_entry(ROOT)

CHECKS.reject { |_description, expected, actual| expected == actual }.then do |failures|
  puts
  if failures.empty?
    puts "#{CHECKS.size} checks passed"
    puts "DRIVE OK"
  else
    failures.each do |description, expected, actual|
      warn "FAILED #{description}: expected #{expected.inspect}, got #{actual.inspect}"
    end
    exit(1)
  end
end
