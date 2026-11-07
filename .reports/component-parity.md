# Component parity — Authenticator

| | |
|---|---|
| Upstream | `origin/master` @ `af7aed5` |
| Port | `ruby` @ `a1a4062` |
| Units with full four-axis parity confirmed | 0 / 24 (see below — "confirmed" requires Step 4/5 driving, which the committed drive scripts do for most but not all units) |
| Units built, with a widget/CSS/behaviour match and *no* drive coverage | 2 / 24 (`lib/file_choosers.rb`, `lib/clickable_settings_box.rb`) |
| Units built, behaviour-driven, text axis failing | 1 group (settings/backup/password/GPG windows, see Translation finding below) |

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
