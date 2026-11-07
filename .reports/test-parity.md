# Test parity — Authenticator

| | |
|---|---|
| Upstream | `origin/master` @ `af7aed5` |
| Port | `ruby` @ `a1a4062` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Drive command | `nix develop --command xvfb-run -a ruby test/drive_authenticator.rb` and same for `test/drive_backup_and_search.rb` |

## Upstream has no test suite

Verified directly, not assumed:

```
$ git ls-tree -r --name-only origin/master | grep -i test
search-provider/...   # the search-provider's own .ini/.service, not a test
$ git show origin/master:meson.build | grep -i test     # (no meson.build — this is a meson-less, autotools-less Python/Flatpak project)
$ cat .gitlab-ci.yml   # one stage: build the flatpak. No test invocation anywhere.
```

No `def test_*`, no `unittest`, no `pytest`, no `tests/` or `test/`
directory, and no test target in any build file (there is no `meson.build`
at the project root at all — `data/meson.build` and `po/meson.build` only
cover install rules). Parity is **0/0 and is met trivially.**

**The port therefore inherits no safety net.** Every behaviour the port gets
right, it gets right because someone read the Python and reproduced it
correctly by hand — not because any upstream test would have caught a
regression. That is the finding this degenerate case exists to surface, and
it is stated here explicitly rather than left as an implication of a clean
0/0 row.

## Extra — what the port runs instead

- `test/drive_authenticator.rb` — 54 checks, run and passing live under
  `nix develop --command xvfb-run -a ruby`. Drives account creation, OTP
  generation against RFC 6238 test vectors, search, selection mode and
  deletion, the countdown/progress bar, add/edit windows, the settings
  window's three pages and dark-theme toggle, the backup page's rows, the
  password window, JSON export/import at the model level, the empty state,
  every registered menu action, the about window and the clear-database
  action.
- `test/drive_backup_and_search.rb` — 51 checks, run and passing live.
  Drives GPG encrypt/decrypt round-trips (including a wrong-passphrase
  rejection and the "no half-written file" check), the QR reader against
  `zbarimg` (including a non-QR negative case), the OpenPGP export/import
  round-trip through `GPGRestoreWindow`/`FingprintPGPWindow`, and the GNOME
  Shell search-provider D-Bus interface end to end.
- `test/support/mock_gnome_shell_screenshot.rb` — a harness file (per this
  skill's own exclusion rule for `*mock*`/`*support*`), not a test.

105/105 checks pass, 0 failures, matching the runtime gate this round
(`drive_ok=true`). Both scripts were re-run in this audit, live, under the
dev shell's `xvfb-run`, not taken on faith from the gate's own report.

## The gap the gate's own count does not show

"105 checks … 24 components" is read elsewhere by this org's gate as
coverage of the whole port. It is not: `grep` over both drive scripts for
`ClickableSettingsBox`, `clickable_settings_box` and `FileChoosers` returns
nothing. `lib/file_choosers.rb` and `lib/clickable_settings_box.rb` are two
of the 24 components in `.reports/component-inventory.md` and neither is
touched by either script — the export/import checks call
`Authenticator::BackupJson` directly and never go through the
`Gtk::FileChooserNative` widgets those two files wrap. See
`.reports/component-parity.md`, Finding 1, for the detail. 105 checks is a
real, re-run, passing number; it is not evidence that all 24 components were
exercised, and this round's instruction to treat an unexercised component as
a gap in its own right applies to these two.

## Rules this ledger follows

No upstream test exists for this ledger to lower, merge or skip — the only
way this ledger could misrepresent parity is by implying the drive scripts
*are* ported upstream tests (they are not: they are extra, and they stay
extra) or by letting their count stand in for full-app coverage (addressed
above).
