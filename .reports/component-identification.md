# Component identification — Authenticator

| | |
|---|---|
| Upstream | `origin/master` @ `af7aed5` (Python + PyGObject, GTK3, no `.ui`/`.blp`) |
| Port | `ruby` @ `5517c46` (re-checked for drift again; `7a96bc2`'s inventory refresh already corrected the Line 73 drift noted below, and `5517c46` added `exe/authenticator`'s CLI flags — see new item below) |

This skill's own inventory was already produced and committed at
`.reports/component-inventory.md` (first written at `f28b86c`, re-committed at
`7368740` after the GPG/QR/search-provider port landed). It is read here, not
redone, and checked for drift against the tree as it stands now rather than
as it stood when it was written.

## What is still accurate

- The file-by-file widget/CSS/signal/action tables (24 user-facing
  components across 10 upstream widget files) match what is in `lib/` today.
  Spot-checked: `lib/settings_window.rb`, `lib/gpg_restore_window.rb`,
  `lib/gpg_fingerprint_window.rb`, `lib/password_window.rb`,
  `lib/account_config.rb`, `lib/header_bar.rb`, `lib/accounts_widget.rb`.
- The "Supporting (non-widget) upstream files" section (11 model/support
  files) and the "Blockers" section (GTK3→4 replacements, the
  `AccountsManager` thread→`GLib::Timeout` substitution, the two upstream
  dead-code paths) still read true against the current source.
- `data/data.json` and `data/icons/**` are byte-identical to upstream (the
  report's claim that the provider database "landed" is correct — verified
  with `diff`).

## What has drifted (stale, not re-verified since being written)

1. **Line 73 — already fixed.** The version of this report written against
   `a1a4062` found a stale "deliberately unregistered until the GPG model
   lands" claim at `component-inventory.md:73`. Re-read now: `7a96bc2`
   (the next inventory refresh) rewrote that paragraph to state plainly
   that `app.import_pgp_json`/`app.export_pgp_json` are registered today
   and names the correction explicitly. Confirmed by reading
   `component-inventory.md:79-85` at HEAD. No action needed.

2. **New since `a1a4062` — `exe/authenticator` now has a component this
   report's prior pass had no file to check.** `5517c46` ported
   `authenticator.py.in`'s `--debug`/`--version` CLI into `exe/authenticator`
   for the first time. Component-identified: an `OptionParser` with two
   flags, matching upstream's `argparse` two flags one-for-one on
   behaviour. Not re-exported to translation (see
   `.reports/translation-parity.md`) and its `--version` exit
   code/stream diverges from upstream (see `.reports/component-parity.md`
   Finding 5) — both filed there, not repeated here, since this step only
   owns identification, not the verdict.

## Gap this step cannot close by itself

The inventory enumerates widgets, CSS and signals. It does **not** enumerate
every translatable string per file — that is `translation-parity`'s census,
scoped per file — and the inventory's own prose ("29 upstream msgids
reachable from code... are now marked") turns out, once that census is run
(see `.reports/translation-parity.md`), to undercount by roughly half. The
component-identification step is not wrong here; it simply never claimed to
carry the text axis, and the gap sat invisible until the dedicated census ran.

## Round audit at `c5b0f49`

No new upstream-facing component since the last pass — `c5b0f49` added
test coverage (`test/drive_cli.rb`, the zbar-absent branch in
`test/drive_backup_and_search.rb`) and 4 `N_()`-marked constants in
`lib/settings.rb`, none of which are new widgets, CSS, signals or actions.
The 24 widget units + the `exe/authenticator` CLI unit (25 total) identified
by the previous rounds still match `lib/`/`exe/` one-for-one against
`origin/master`.

One correction that belongs at this step rather than in `component-parity.md`
or `translation-parity.md`: the `N_()` constants `c5b0f49` added to
`lib/settings.rb` are not attached to any widget this inventory tracks —
they describe a GSettings schema the port does not install (the JSON-file
substitution already recorded). They are source-level only; see
`.reports/translation-parity.md` for why marking them in source did not, by
itself, get them into the shipped catalogue.
