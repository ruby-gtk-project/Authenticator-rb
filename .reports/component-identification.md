# Component identification — Authenticator

| | |
|---|---|
| Upstream | `origin/master` @ `af7aed5` (Python + PyGObject, GTK3, no `.ui`/`.blp`) |
| Port | `ruby` @ `a1a4062` |

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

1. **Line 73** — "`app.import_pgp_json` and `app.export_pgp_json` are
   deliberately unregistered until the GPG model lands." The GPG model
   landed two commits later (`fab3359`), and both actions are now
   registered and wired (`lib/application.rb:49-50`, `on_import_pgp_json`
   calling `FileChoosers.import_pgp_json`, `on_export_pgp_json` calling
   `FileChoosers.export_pgp_json`). The sentence was never updated and now
   describes a state the tree is no longer in. A reader trusting this line
   today would believe two actions are missing when they are not — stale
   documentation, filed under `accountability-ensurance` below because an
   unreviewed claim in a committed report is exactly the failure mode that
   skill exists to catch, even though the direction of the error (claiming
   less than exists, not more) is the harmless direction.

## Gap this step cannot close by itself

The inventory enumerates widgets, CSS and signals. It does **not** enumerate
every translatable string per file — that is `translation-parity`'s census,
scoped per file — and the inventory's own prose ("29 upstream msgids
reachable from code... are now marked") turns out, once that census is run
(see `.reports/translation-parity.md`), to undercount by roughly half. The
component-identification step is not wrong here; it simply never claimed to
carry the text axis, and the gap sat invisible until the dedicated census ran.
