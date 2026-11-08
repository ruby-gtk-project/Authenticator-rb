# frozen_string_literal: true

# Drives the OpenPGP backup path, the QR-code scanner, the GNOME Shell
# screenshot interface and the Shell search provider, so each claim about them
# can be checked rather than asserted:
#
#   nix develop --command dbus-run-session -- xvfb-run -a \
#     ruby test/drive_backup_and_search.rb
#
# A session bus is needed because the screenshot model and the search provider
# both live on it: the script stands up a mock org.gnome.Shell.Screenshot of
# its own, and registers the real search provider and calls it back over the
# bus with `gdbus`.
#
# Every account, token, setting, GPG key and temporary file this creates lives
# under a throwaway XDG_CONFIG_HOME, XDG_DATA_HOME, XDG_CACHE_HOME and GPG
# home that are removed on the way out, so the run never touches the real
# store or the real keyring.

require "fileutils"
require "json"
require "tmpdir"

ROOT = Dir.mktmpdir("authenticator-drive-backup")
ENV["XDG_CONFIG_HOME"] = File.join(ROOT, "config")
ENV["XDG_DATA_HOME"] = File.join(ROOT, "data")
ENV["XDG_CACHE_HOME"] = File.join(ROOT, "cache")
FileUtils.mkdir_p(ENV.fetch("XDG_CACHE_HOME"))

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "authenticator"
require "shell_search_provider"

# The QR code the mock shell draws when the model asks it for a screenshot,
# and the token inside it.
SCAN_SECRET = "MFRGGZDFMZTWQ2LK"
SCAN_URI = "otpauth://totp/Slack:slacker?secret=#{SCAN_SECRET}"

# The mock goes up first so it has acquired its name by the time the checks
# below reach the bus. It is a separate process, not a fork: GDBus keeps a
# worker thread per connection and a forked child inherits the connection
# without the thread, so a forked mock never acquires anything.
MOCK_PID = Process.spawn(
  RbConfig.ruby,
  File.expand_path("support/mock_gnome_shell_screenshot.rb", __dir__),
  SCAN_URI,
)

CHECKS = []

def check(description, expected, actual)
  CHECKS << [description, expected, actual]
  puts(format("%-54s %-30s %s", description, expected.inspect, actual.inspect))
end

# Keep the port's own logging out of the driver's output.
Authenticator::Logger.default = Authenticator::Logger.new(io: File.open(File::NULL, "w"))

# A GPG home of this run's own, with one key in it whose passphrase the
# restore window will be given.
GPG_HOME = File.join(ROOT, "gnupg")
PASSPHRASE = "correct horse battery staple"
FileUtils.mkdir_p(GPG_HOME, mode: 0o700)
Authenticator::Settings.default.gpg_location = GPG_HOME

system(
  "gpg", "--homedir", GPG_HOME, "--batch", "--yes", "--no-tty",
  "--pinentry-mode", "loopback", "--passphrase", PASSPHRASE,
  "--quick-generate-key", "Authenticator Drive <drive@example.invalid>",
  "default", "default", "never",
  out: File::NULL,
  err: File::NULL,
) || abort("could not generate a GPG key to drive with")

# --- the GPG model -----------------------------------------------------

gpg = Authenticator::Gpg.new(home: GPG_HOME)
check("gpg is on PATH", true, Authenticator::Gpg.available?)
check("the keyring has one public key", 1, gpg.keys["public"].size)
check("and one secret key", 1, gpg.keys["private"].size)
check("the key's uid came back", true, gpg.keys["public"].first["uids"].first.include?("Authenticator Drive"))
FINGERPRINT = gpg.keys["public"].first["fingerprint"]
check("its fingerprint is 40 hex digits", true, FINGERPRINT.match?(/\A[0-9A-F]{40}\z/))

gpg.encrypt_json(%({"hello":"world"}), FINGERPRINT).then do |status|
  check("encrypting to it worked", true, status.ok)
  check("and produced an armoured message", true, status.data.start_with?("-----BEGIN PGP MESSAGE-----"))

  File.join(ROOT, "round-trip.asc").then do |ciphertext|
    File.write(ciphertext, status.data)
    File.join(ROOT, "round-trip.json").then do |plaintext|
      # The wrong passphrase goes first: gpg-agent caches a key once it has
      # been unlocked, so after a successful decrypt it would stop asking.
      check(
        "a wrong passphrase is refused",
        false,
        gpg.decrypt_json(ciphertext, "not the passphrase", "#{plaintext}.wrong").ok,
      )
      check("and leaves no half-written file", false, File.exist?("#{plaintext}.wrong"))
      check("decrypting it back worked", true, gpg.decrypt_json(ciphertext, PASSPHRASE, plaintext).ok)
      check("and recovered the message", { "hello" => "world" }, JSON.parse(File.read(plaintext)))
    end
  end
end

# --- the QR reader -----------------------------------------------------

check("zbarimg is on PATH", true, Authenticator::QrReader.available?)

QR_SECRET = "JBSWY3DPEHPK3PXP"
File.join(ROOT, "code.png").then do |image|
  system(
    "qrencode", "-s", "8", "-o", image,
    "otpauth://totp/GitHub:me@example.com?secret=#{QR_SECRET}&issuer=GitHub",
    out: File::NULL,
    err: File::NULL,
  ) || abort("could not write a QR code to read")

  Authenticator::QrReader.new(image).then do |reader|
    check("nothing is valid before a read", false, reader.valid?)
    check("the reader found the secret", QR_SECRET, reader.read)
    check("and kept the rest of the query", "GitHub", reader.codes["issuer"])
    check("the scan is a usable token", true, reader.valid?)
    check("and the image was deleted", false, File.exist?(image))
  end
end

File.join(ROOT, "not-a-code.png").then do |image|
  system("qrencode", "-s", "8", "-o", image, "plain text, no URI", out: File::NULL, err: File::NULL)
  Authenticator::QrReader.new(image).then do |reader|
    check("a non-URI code reads as nothing", nil, reader.read)
    check("and is not a usable token", false, reader.valid?)
  end
end

# --- the zbar-absent path -----------------------------------------------
#
# Nothing above flips AccountConfig.can_scan? to false: the suite only ever
# asserts zbarimg IS on PATH. Upstream turns its scan button off and shows a
# "zbar library is not found" notification when pyzbar's import fails; the
# port's equivalent is the scan button never going into the header bar at
# all, because AddAccountWindow only packs it in when `can_scan?` is true.
# `can_scan?` is stubbed here rather than PATH actually cleared, since
# `available?` also depends on Screenshot's own bus check; stubbing is the
# alternative this gap names, and it isolates exactly the branch the window
# takes on the false answer.
class << Authenticator::AccountConfig
  alias_method(:__real_can_scan?, :can_scan?)

  def can_scan? = false
end

Authenticator::AddAccountWindow.new(nil).tap do |adder|
  check("with no decoder, build still succeeds", true, !!adder.build)
  check("and the scan button's memoized method was never called", nil, adder.instance_variable_get(:@scan_button))
end

class << Authenticator::AccountConfig
  alias_method(:can_scan?, :__real_can_scan?)
  remove_method(:__real_can_scan?)
end

check("can_scan? is back to the real answer", true, Authenticator::AccountConfig.can_scan?)

# --- the backup round trip through the restore window ------------------

Authenticator::Account.create("me@example.com", "GitHub", QR_SECRET)
Authenticator::Account.create("work", "Amazon", "KRSXG5CTMVRXEZLU")
check("two accounts to back up", 2, Authenticator::Database.default.count)

ENCRYPTED_BACKUP = File.join(ROOT, "backup.json.asc")
check(
  "the OpenPGP export wrote the file",
  true,
  Authenticator::BackupPgpJson.export_file(ENCRYPTED_BACKUP, FINGERPRINT),
)
check("and it is armoured", true, File.read(ENCRYPTED_BACKUP).start_with?("-----BEGIN PGP MESSAGE-----"))
check(
  "exporting to an unknown key fails rather than writing rubbish",
  false,
  Authenticator::BackupPgpJson.export_file("#{ENCRYPTED_BACKUP}.bad", "0" * 40),
)
check("leaving no file behind", false, File.exist?("#{ENCRYPTED_BACKUP}.bad"))

# --- the two GPG windows -----------------------------------------------

# The fingerprint window lists what is in the keyring and hands back the
# fingerprint of whichever row was activated, which is how the export above
# learns which key to encrypt to.
Authenticator::GpgFingerprintWindow.new(nil, on_selected: ->(f) { @selected = f }).tap do |window|
  window.build
  check(
    "the fingerprint window has both sections",
    ["Public keys", "Private keys"],
    [window.public_group.title, window.private_group.title],
  )
  check("one row per public key", 1, window.key_rows("public").size)
  window.key_rows("public").first.action_row.then do |row|
    check("titled with the key's uid", true, row.title.include?("Authenticator Drive"))
    check("and subtitled with its fingerprint", FINGERPRINT, row.subtitle)
  end
  window.key_rows("public").first.build.activate
end
check("activating a row handed back the fingerprint", FINGERPRINT, @selected)

# The restore window is the other half of the OpenPGP backup: it asks for the
# passphrase, decrypts, and imports what came out. Clearing the store first is
# what makes the import observable.
Authenticator::Database.default.clear
Authenticator::Keyring.clear
Authenticator::AccountsManager.default.clear
check("the store is empty before the restore", 0, Authenticator::Database.default.count)

@imported = []
Authenticator::GpgRestoreWindow.new(
  nil,
  ENCRYPTED_BACKUP,
  on_imported: ->(account) { @imported << account },
).tap do |window|
  window.build
  check("the restore window asks for a paraphrase", "Paraphrase", window.paraphrase_widget.entry_row.title)

  # The wrong-paraphrase case is checked against the Gpg model higher up,
  # before anything has unlocked the key. It cannot be checked again here:
  # gpg-agent has the key cached by now and decrypts whatever it is given,
  # which is the agent's behaviour and not the window's.
  window.paraphrase_widget.text = PASSPHRASE
  window.send(:on_apply)
end
check("the restore brought both accounts back", 2, Authenticator::Database.default.count)
check("and told the caller about each one", 2, @imported.size)
check(
  "with their providers intact",
  %w[Amazon GitHub],
  Authenticator::Database.default.accounts.map { |row| row["provider"] }.sort,
)
check(
  "and their tokens",
  [QR_SECRET],
  Authenticator::Database.default.accounts.filter_map { |row|
    Authenticator::Keyring.get_by_id(row["secret_id"])
  }.select { |token| token == QR_SECRET },
)
check(
  "leaving no decrypted copy behind",
  [],
  Dir.glob(File.join(ENV.fetch("XDG_CACHE_HOME"), "authenticator-restore-*")),
)

# --- the search provider's own methods ---------------------------------

PROVIDER = Authenticator::ShellSearchProvider.new
check("the search provider found its interface", "org.gnome.Shell.SearchProvider2", PROVIDER.interface_info.name)
check("searching by username", 1, PROVIDER.search(%w[me]).size)
check("searching by nothing matches everything", 2, PROVIDER.search([]).size)
PROVIDER.search(%w[me]).first.then do |found|
  check(
    "the metas carry the name and the provider",
    [{ "id" => found, "name" => "me@example.com", "description" => "GitHub - me@example.com" }],
    PROVIDER.result_metas([found]),
  )
  SEARCH_ID = found
end
check("a stale id is skipped rather than fatal", [], PROVIDER.result_metas(%w[9999]))

# --- everything that needs the session bus -----------------------------

require "gio2"

# The search provider goes on the same bus, so the gdbus call below has
# something to talk to.
PROVIDER.build
SEARCH_REPLY = File.join(ROOT, "search-reply.txt")

MAIN_LOOP = GLib::MainLoop.new

GLib::Timeout.add(1_500) do
  check("the mock shell is on the bus", true, Authenticator::Screenshot.available?)
  check("SelectArea came back", [10, 20, 300, 300], Authenticator::Screenshot.select_area)

  Authenticator::Screenshot.area.then do |shot|
    check("the screenshot was saved", true, File.file?(shot.to_s))
    check("and lives in the cache directory", true, shot.to_s.start_with?(ENV.fetch("XDG_CACHE_HOME")))
    check("the scanner read the token out of it", SCAN_SECRET, Authenticator::QrReader.new(shot).read)
  end

  # The provider's five methods, over the bus, by the names GNOME Shell calls
  # them. gdbus runs in a child so this process can keep serving the calls.
  Process.spawn(
    "bash", "-c",
    [
      "gdbus call --session --dest #{Authenticator::ShellSearchProvider::BUS_NAME}",
      "--object-path #{Authenticator::ShellSearchProvider::OBJECT_PATH}",
      "--method org.gnome.Shell.SearchProvider2.GetInitialResultSet '[\"me\"]'",
      "> #{SEARCH_REPLY} 2>&1;",
      "gdbus call --session --dest #{Authenticator::ShellSearchProvider::BUS_NAME}",
      "--object-path #{Authenticator::ShellSearchProvider::OBJECT_PATH}",
      "--method org.gnome.Shell.SearchProvider2.GetResultMetas '[\"#{SEARCH_ID}\"]'",
      ">> #{SEARCH_REPLY} 2>&1;",
      # The void-return path. `authenticator` is not on PATH in the dev shell,
      # so the launch fails and is logged — what is being checked is that the
      # method still answers rather than leaving the Shell waiting.
      "gdbus call --session --dest #{Authenticator::ShellSearchProvider::BUS_NAME}",
      "--object-path #{Authenticator::ShellSearchProvider::OBJECT_PATH}",
      "--method org.gnome.Shell.SearchProvider2.LaunchSearch '[\"me\"]' 0",
      ">> #{SEARCH_REPLY} 2>&1;",
      "gdbus call --session --dest #{Authenticator::ShellSearchProvider::BUS_NAME}",
      "--object-path #{Authenticator::ShellSearchProvider::OBJECT_PATH}",
      "--method org.gnome.Shell.SearchProvider2.ActivateResult '#{SEARCH_ID}' '[\"me\"]' 0",
      ">> #{SEARCH_REPLY} 2>&1",
    ].join(" "),
  ).then { |pid| Process.detach(pid) }

  false
end

GLib::Timeout.add(4_500) do
  File.read(SEARCH_REPLY).then do |reply|
    check("GetInitialResultSet answered over the bus", true, reply.include?("(['#{SEARCH_ID}'],)"))
    check("GetResultMetas named the account", true, reply.include?("me@example.com"))
    check("and described it", true, reply.include?("GitHub - me@example.com"))
    check("LaunchSearch and ActivateResult both answered", 2, reply.scan(/^\(\)$/).size)
    check("and no call came back an error", false, reply.include?("Error"))
  end
  MAIN_LOOP.quit
  false
end

MAIN_LOOP.run

Process.kill("TERM", MOCK_PID)
Process.wait(MOCK_PID)
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
