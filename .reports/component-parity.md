# Component parity — Authenticator

| | |
|---|---|
| Upstream | `origin/master` @ `af7aed5` |
| Port | `ruby` @ `5517c46` (re-audited; this file's own header was last bumped at `a1a4062`, three commits behind HEAD — see "Update 2" below) |
| Units with full four-axis parity confirmed | 22 / 24 (file-choosers and clickable-row Finding 1 closed, text-axis Finding 2 closed for every row with a call site) |
| Units with a widget/CSS/behaviour match but an open text-axis or CLI-help gap | 2 (the CLI entry point's `--debug`/`--version` help strings; see Update 2) |
| Components outside the 24-unit widget count that are still wholly unported | 1 (`data/*.appdata.xml.in` — no AppStream metainfo file exists anywhere in the port) |

## Method

Built on `.reports/component-identification.md`'s file mapping. For each of
the 24 units, read the upstream file and its port file side by side for
widget type/count, CSS, signals and actions (Steps 1-3), then checked whether
`test/drive_authenticator.rb` / `test/drive_backup_and_search.rb` actually
fires the behaviour (Step 5) rather than trusting that a `connect`/`on_*`
exists. Both drive scripts were run live under `nix develop --command
xvfb-run -a ruby` (54 + 51 = 105 checks, all passing — matches the runtime
gate).

## Finding 1 — two components are built correctly but driven by nothing

`lib/file_choosers.rb` (the `Gtk::FileChooserNative` wrappers for
import/export JSON, import/export OpenPGP JSON and the GPG-location folder
picker — upstream `Authenticator/widgets/utils.py`) and
`lib/clickable_settings_box.rb` (the settings row that opens that folder
picker — upstream's clickable row in `widgets/settings.py`) have **zero**
occurrences in either drive script:

```
$ grep -n "ClickableSettingsBox\|clickable_settings_box\|FileChoosers" test/*.rb
(no output)
```

The backup checks in `test/drive_authenticator.rb` ("the export wrote every
account", "the import brought them back") call
`Authenticator::BackupJson.export_file` / `.import_file` **directly**,
bypassing the `Gtk::FileChooserNative` dialog entirely. That proves the
backup *model* works; it proves nothing about the file-picker *widget* —
whether it opens, whether its filters are `JSON files` / `Encrypted GPG
files` as upstream's are, whether cancelling it leaves state untouched, or
whether the GPG-location row actually opens a folder (not file) chooser and
writes the picked path back to `Settings`.

Per the brief for this round: a component no check exercises is unverified,
not done. These two are built — the code reads correctly against upstream —
but "built and never run" is not the same claim as "has parity," and the
committed `105 checks / 24 components` figure overstates what was actually
driven by counting these two as covered when no row in either script touches
them.

## Finding 2 — the backup/settings/GPG windows are driven, but their text axis was never checked against upstream

Widget type, count, CSS and signal/action axes for `lib/settings_window.rb`,
`lib/gpg_fingerprint_window.rb`, `lib/gpg_restore_window.rb` and
`lib/password_window.rb` all match upstream — confirmed by direct read
against `Authenticator/widgets/settings.py` and
`Authenticator/widgets/backup/gnupg.py` and by the drive scripts, which do
exercise the dark-theme switch, the settings pages, the GPG fingerprint
list, the GPG restore flow and the password window's Save-button sensitivity.

The text axis fails on all four files: every label, title and group heading
in them is a bare Ruby string literal with no `_()`/`GetText` marker at all —
`"Appearance"`, `"Behaviour"`, `"Dark theme"`, `"Clear the database"`,
`"GPG keys location"`, `"Backup password"` (upstream: `"Backup Password"`,
capital P — reworded as well as unmarked), `"GPG fingerprint"`,
`"Public keys"`, `"Private keys"`, `"Backup Password"` /
`"Old Password"` / `"Password"` / `"Repeat Password"` in
`lib/password_window.rb`. Full list and upstream sites in
`.reports/translation-parity.md`. This is a parity gap on the fourth axis for
every row of these four units' tables — none of them can be marked `parity`
— and it was not caught by any committed report because no report ran the
text-axis census on these files; `.reports/component-inventory.md` lists them
as "exists" on the widget axis and says nothing about text.

## What does hold

- Widget/CSS/signal axes for all 24 units check out against upstream, modulo
  the documented, explained substitutions already in
  `.reports/component-identification.md` (GSettings → JSON file,
  `Gtk.ComboBox`+completion → completion only, libgd notification → Adwaita
  toast, GTK3 `Gd`/`Gdk.Screen` CSS plumbing → GTK4 equivalents).
- `data/style.css` carries every upstream rule (reformatted, one rule — the
  `.account-row:selected GtkImage` → `.account-row:selected image` type
  selector — re-expressed for GTK4's css-name change, a correspondence per
  the skill's own worked example) plus one new rule, `.username`, which is
  an addition, not a divergence, and is not otherwise suspicious.
- `data/data.json` and every provider icon under `data/icons/` are
  byte-identical to upstream (`diff` returns nothing).

## Verdict

Not clean. Two components (file choosers, clickable GPG-location row) are
unverified by any check; four components (settings/password/GPG windows)
fail the text axis across roughly two dozen strings. Neither failure is
visible in the committed `.reports/component-inventory.md`, which reports
only the widget/CSS/signal axes and calls the units "exists."

## Update — Finding 1 closed; Finding 2 closed for the rows with a call site

Both drive scripts now exercise the two previously-unverified components for
real, through the production entry points rather than the backend model:

- `test/drive_authenticator.rb` fires `settings_window.gpg_location_row`'s
  actual `activated` signal (not a call to `on_gpg_location`) and asserts
  `Settings.default.gpg_location` and the row's own subtitle both pick up
  the chosen folder.
- The same script activates the real `app.import_json` / `app.export_json`
  / `app.import_pgp_json` / `app.export_pgp_json` actions — the same
  `Gio::SimpleAction`s the primary menu's items invoke — and asserts both on
  the `Gtk::FileFilter` name `FileChoosers` built (`"JSON files"` /
  `"Encrypted GPG files"`) and on the chosen-path callback's effect (the
  file written, the account count unchanged on a re-import, the GPG
  fingerprint/restore window that callback opens).
- Since there is no `xdg-desktop-portal` under Xvfb for `Gtk::FileDialog` to
  talk to, `test/support/fake_file_dialog.rb` stands in only for that native
  round trip (`open`/`save`/`select_folder` and their `_finish` calls); every
  line of `FileChoosers`' and `ClickableSettingsBox`'s own code — filter
  construction, signal wiring, `finish`'s `file.path` extraction — runs
  unmodified. Both drive scripts were run live under `nix develop --command
  xvfb-run -a ruby`: 64 + 51 = 115 checks, all passing.

Finding 2's text-axis gap is closed for every row that had a port call
site — see `.reports/translation-parity.md`'s update for the exact count
(53/66 ported, 13 gap, down from 36) — leaving only the rows with no call
site at all, which this report's Finding 2 did not claim to fix either.

## Update 2 — re-driven live at HEAD (`5517c46`), three new findings

Re-ran both drive scripts under `nix develop --command xvfb-run -a ruby`
directly rather than trusting the committed numbers: **64 + 51 = 115 checks,
0 failed, `DRIVE OK` both times** — the runtime gate's figure is real, not
quoted from an earlier run.

**Finding 3 — the AppStream metainfo component was never started.**
`Authenticator/` upstream carries
`data/com.github.bilelmoussaoui.Authenticator.appdata.xml.in` (6 marked
strings: the one-line and long descriptions, the "Features:" heading and its
three bullets) plus a `.desktop.in` file. Neither has a port-side file at
all — not a stub, not a placeholder, nothing under `data/`. This is honestly
disclosed in `.reports/component-inventory.md` ("stays a gap"), so it is not
a false claim, but it is still an un-ported component and belongs in this
report's count: **24 widget units + the application-class unit have parity;
the AppStream/desktop-file unit does not exist.**

**Finding 4 — `exe/authenticator`'s own `--debug`/`--version` help text is a
plain miss, not a substitution.** `5517c46` ported `authenticator.py.in`'s
CLI parsing faithfully for *behaviour* (same two flags, same semantics,
confirmed by reading `exe/authenticator` against `authenticator.py.in`) but
the file does not `require_relative "i18n"` or call `_()` anywhere, so the
two `OptionParser#on` description strings that upstream marks with `_()`
are bare literals in the port. Unlike the GSettings-schema and
zbar-notification cases (architectural substitutions, recorded as such),
there is no substitution story here — it is simply unmarked. See
`.reports/translation-parity.md`.

**Finding 5 — the same commit changes `--version`'s exit behaviour and
nobody drove it.** Upstream: `sys.exit("Version : " + str(VERSION))` — in
Python, `sys.exit(<str>)` prints the string to **stderr** and exits with
status **1**. Port (`exe/authenticator`): `puts("Version : #{...}")` prints
to **stdout** and then falls off the end of the script, exiting status
**0**. Neither drive script, nor anything else in the repo, invokes
`exe/authenticator` as a subprocess and checks its exit code or which
stream it wrote to — both drive scripts talk to the app's Ruby classes
in-process, never through `exe/authenticator` itself. So this is a real,
confirmed-by-reading behavioural divergence (stream and exit code both
flipped) on a component (the CLI entry point) that no check in the suite
touches at all, in either direction.

## Verdict (current)

Not clean. Findings 1 and 2 from the original pass are closed. Three
findings remain open: the AppStream/desktop-file component is entirely
unported (Finding 3, already disclosed elsewhere), the CLI help text is
unmarked for translation with no substitution excuse (Finding 4), and the
`--version` flag's exit code/stream changed from upstream with zero test
coverage in either direction (Finding 5, newly found this pass).
