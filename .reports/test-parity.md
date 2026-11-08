# Test parity — Authenticator

| | |
|---|---|
| Upstream | `origin/master` @ `af7aed5` |
| Port | `ruby` @ `75684c0` (re-run; `da96fed` landed the file-choosers drive coverage described below as still-missing in the version of this report written at `a1a4062`; `75684c0` ported the AppStream/desktop files and fixed `exe/authenticator`'s CLI-help marking and `--version` exit behaviour, closing one of the two "nothing executes this" findings below) |
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

- `test/drive_authenticator.rb` — **64 checks** (up from 54 — `da96fed`
  added the file-choosers/clickable-settings-row coverage described in the
  gap section below as missing, plus the GPG-location-row drive), run and
  passing live under
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

**115/115 checks pass (64+51), 0 failures**, matching this round's runtime
gate (`drive_ok=true`, 115 checks, 0 failed). Both scripts were re-run in
this audit, live, under the dev shell's `xvfb-run`, not taken on faith from
the gate's own report.

## `file_choosers.rb`/`clickable_settings_box.rb` gap: closed

The previous version of this report (written against `a1a4062`) found that
`lib/file_choosers.rb` and `lib/clickable_settings_box.rb` had zero
occurrences in either drive script. `da96fed` fixed this: both scripts now
fire the real `app.import_json`/`export_json`/`import_pgp_json`/
`export_pgp_json` actions and the GPG-location row's actual `activated`
signal — confirmed by reading `test/drive_authenticator.rb:205-290`, not
just by the file's own commit message. This is now closed.

## One component the gate's "115 checks, 25 components" figure still does not reach

1. **The zbar-absent path.** `test/drive_backup_and_search.rb` asserts
   `"zbarimg is on PATH" → true` as a *precondition* before every QR check
   that follows. No check anywhere sets `PATH` to exclude `zbarimg` and
   verifies `AccountConfig.can_scan?` goes false / the scan button is never
   built. The branch exists in `lib/qr_reader.rb` and `lib/add_account_window.rb`
   and is read as correct, but it has never been executed by anything in
   this repo. See `.reports/component-parity.md`'s sibling note
   and `.reports/translation-parity.md`'s zbar-notification gap.

Per this round's instruction, a component no check exercises is unverified,
not done — this stays an open finding even though the code it guards reads
correctly.

A second component this section previously listed —
`exe/authenticator`, invoked as a process rather than through the port's
Ruby classes in-process — is **closed** as a behavioural finding:
`75684c0` fixed the `--version`/stderr/exit-1 divergence from upstream
(confirmed live this round: `nix develop --command xvfb-run -a ruby
exe/authenticator --version` writes to stderr and exits 1). The process
itself is still never shelled out to and checked by either drive script,
so a future regression there would again go uncaught by anything in this
repo — recorded here as a standing process gap, distinct from the now-fixed
behaviour it previously masked.

## Rules this ledger follows

No upstream test exists for this ledger to lower, merge or skip — the only
way this ledger could misrepresent parity is by implying the drive scripts
*are* ported upstream tests (they are not: they are extra, and they stay
extra) or by letting their count stand in for full-app coverage (addressed
above).

## Round audit at `c5b0f49` — both previously-open gaps closed, reproduced live

`c5b0f49` ("Close the gschema-summary, zbar-absent and CLI-subprocess test
gaps") added `test/drive_cli.rb` and extended
`test/drive_backup_and_search.rb`. Re-ran all three scripts live:

```
test/drive_authenticator.rb       64 checks, DRIVE OK
test/drive_backup_and_search.rb   54 checks, DRIVE OK  (was 51; +3 for the
                                   zbar-absent stub added this round)
test/drive_cli.rb                 9 checks,  DRIVE OK  (new this round)
```

64 + 54 + 9 = **127 checks, 0 failures** — matches this round's runtime gate
(`drive_ok=true`, 127 checks, 0 failed, 25 components) exactly, confirmed by
running the commands myself rather than taking the committed total on
faith.

Both findings this file's previous round left open are closed:

- **The zbar-absent path** is now driven: `AccountConfig.can_scan?` is
  stubbed to `false`, `AddAccountWindow.new(nil).build` is asserted to still
  succeed, and `@scan_button` is asserted never to have been memoized. This
  is the control-flow half of the gap closed — see
  `.reports/translation-parity.md` for the remaining half (the upstream
  notification string itself still has no analogue anywhere in the port,
  which this test correctly does not claim to cover; it tests that the
  button is suppressed, not that a message is shown, because the port shows
  none).
- **`exe/authenticator` invoked as a process** is now driven:
  `test/drive_cli.rb` shells out to it for real with `Open3.capture3` /
  `Process.spawn`, checking exit codes and which stream each flag writes
  to. This closes the "process itself is still never shelled out to" gap
  the previous round left standing.

Upstream still has 0 tests (unchanged — re-confirmed `git ls-tree -r
--name-only origin/master | grep -i test` returns nothing). Parity remains
0/0, met trivially; the 127 checks above are extra coverage the port
carries for its own regression safety, not ported upstream tests, and this
file does not claim otherwise.

## Verdict (current)

Both findings this ledger previously tracked are closed and confirmed live,
not by commit message. No component is currently undriven by either
direction's check. This file's clean status is about test/drive coverage
specifically — it is not a claim about translation-catalogue completeness,
which `.reports/translation-parity.md`'s own round finds still has 13 real
gaps.
