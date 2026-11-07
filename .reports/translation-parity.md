# Translation parity — Authenticator

| | |
|---|---|
| Upstream | `origin/master` @ `af7aed5` |
| Port | `ruby` @ `75684c0` (re-run after `5517c46`, `be7632f`, `75684c0` landed on top of the `a1a4062` snapshot the original version of this report was written against) |
| Domain | `Authenticator` |
| Upstream messages (source census, not the stale `.pot`) | **66** distinct `(msgctxt, msgid)` keys |
| Ported (marked, byte-identical, in the port's source) | **61** (53 at the original census + 6 appdata strings + 2 CLI strings, both closed by `75684c0` — see "Update" and the correction below) |
| Gaps | **5** (4 GSettings-schema summaries, 1 zbar-absent notification — see "The 13 real gaps" below; 8 of the original 13 are now closed) |
| Upstream languages | 14 `.po` files (`ar, da, de, es, fr, hu, id, nb_NO, nl, nl_BE, pl, sr, sr@latin, sv`) |
| Languages shipped by the port | 14 (file list identical, `diff` clean) |

## Method

Ran `.claude/skills/translation-parity/scripts/msgid-census.sh` against an
export of upstream's translatable source (`Authenticator/**/*.py`,
`authenticator.py.in`, `data/*.in`, `data/*.gschema.xml` — 37 files pulled
with `git show origin/master:<path>`) and against the port's `lib/` and
`exe/`. The script's own regex **undercounts by 2**: it does not match
`help=_("...")` inside `argparse.add_argument(...)` calls split across two
lines, so `authenticator.py.in:49,51` ("Start in debug mode", "Authenticator
version number") are invisible to it on *either* side. Caught only by
grepping `authenticator.py.in` directly. The **66** figure above is the automated census (64) plus these 2, confirmed
by hand. The committed `component-parity.md` (written at `a1a4062`, one
commit after the translation work landed) already states "53/66 ported, 13
gap" in passing — this report reproduces that number from a fresh census
rather than trusting the quoted figure, and it holds up.

## The 13 real gaps

**6 — `data/com.github.bilelmoussaoui.Authenticator.appdata.xml.in` was
never ported, so nothing in it has anywhere to be marked:**

```
Beautiful UI
Features:
Huge database of (290+) websites/applications
QR code scanner
Simple application that generates a two-factor authentication code, created for GNOME.
Two-factor authentication code generator
```

The port's `data/` has `style.css`, `data.json`, and the search-provider
`.ini`/`.service.in` (all ported), but no `*.appdata.xml.in` / metainfo file
at all — the GNOME Software "About this app" listing. `component-inventory.md`
already names this as a known, carried-forward gap rather than a silent one,
so it is not an *accountability* finding, but it is still an open parity
gap: the AppStream description is real user-facing text and nobody has
scheduled porting it.

**4 — GSettings key summaries, same root cause as the gschema substitution
documented in `lib/settings.rb`:**

```
Default window maximized behaviour
Default window postiton
Enable/disable night mode within the application
Night mode
```

`lib/settings.rb` deliberately backs these keys with a JSON file instead of
a compiled `.gschema.xml` (no install step needed to run from a checkout —
the same substitution the pilot port makes, and a legitimate one per
`component-parity`'s "replaced by a newer equivalent, with the substitution
recorded" case). But a JSON file has no `<summary>`/`<description>` slots,
so these 4 strings have no home anywhere in the port, marked or not. They
are not user-visible UI text (no GTK dialog shows a GSettings schema
description), so the user-facing impact is close to zero — but they are
real upstream msgids, and the gap is total, not partial.

**2 — the CLI's own `--debug`/`--version` help text is not marked at all,
with no substitution excuse:**

```
Start in debug mode           authenticator.py.in:49  →  exe/authenticator:21 (`OptionParser#on`, plain string)
Authenticator version number  authenticator.py.in:51  →  exe/authenticator:22 (`OptionParser#on`, plain string)
```

`exe/authenticator` does not `require_relative "i18n"` or call `_()`
anywhere — it has no gettext dependency at all. This is the one real gap in
this report that is not inherited or architectural: the strings are present,
visible (`--help` output), and simply never wrapped. Low severity (a CLI
`--help` string, not a window), but it is a plain miss, not a substitution.

**1 — the zbar-missing notification:**

```
zbar library is not found. QRCode scanner will be disabled   Authenticator/widgets/accounts/add.py:264
```

Upstream shows this `Gd.Notification` when `ZBAR_FOUND` is false — i.e. when
the *build* was configured with `ENABLE_QRSCANNER=true` but the `pyzbar`
import nonetheless fails at runtime (an inconsistent-build state). The port's
`QrReader.available?` collapses both of upstream's checks (the build flag and
the runtime import) into one PATH probe for `zbarimg`, done once, with the
scan button simply never built when it is false (`lib/add_account_window.rb`,
`AccountConfig.can_scan?`). That is a reasonable unification — there is no
separate "build enabled it but the runtime half is missing" state possible
in the port — but it does mean the specific notification string, and the
*visible-button-that-then-fails* path it guards, has no analogue to drive.
**No drive script exercises the zbar-absent path at all** (the dev shell
always has `zbarimg` on `PATH` — confirmed: `test/drive_backup_and_search.rb`
asserts `"zbarimg is on PATH" → true` as a *precondition*, never a negative
case). The behaviour for "zbar missing" is therefore asserted by this report
to exist, by reading `lib/add_account_window.rb`, and not verified by
anything that runs.

## What is correct

- The 53 ported msgids are byte-identical to upstream's, msgctxt included
  (spot-checked 12 at random: `"Add a new account"`, `"Backup Password"`,
  `"Clear the database"`, `"Click on items to select them"`,
  `"Couldn't generate the secret code"`, `"Password protect your backup"`,
  `"Restore"`, `"Delete"`, `"Edit"`, `"Select"`, `"Cancel"`, `"Done"` — all
  exact).
- All 14 `.po` files and `po/Authenticator.pot` are present with the same
  filenames as upstream; `po/LINGUAS` matches. The catalogue was rebuilt in
  the commits since the last report (`da96fed`, `7368740`) and every `.po`
  diff in `a1a4062..HEAD` is additive (new msgids gaining translated
  entries), not destructive.
- `rake gettext:po:update`/`gettext:mo:update` were **not independently
  re-run** in this pass either — same unrun-check caveat the previous report
  carried forward. Still unverified, still worth closing.

## Verdict

Not clean. 13 concrete missing msgids, 2 of which (`--debug`/`--version`
help text) are a plain omission rather than an architectural substitution,
and one whole upstream file (the AppStream metainfo) never ported at all.

## Update — CLI help strings marked, AppStream metainfo ported

`exe/authenticator`'s two `OptionParser#on` description strings now route
through `Authenticator._(...)` (the module already carries the bound
`Authenticator` text domain via `lib/i18n.rb`'s `extend GetText`, so no new
`include` site was needed — `Authenticator._("Start in debug mode")` /
`Authenticator._("Authenticator version number")` resolve against the same
catalogue every widget's `_()` call does). This closes Finding 4 from
`.reports/component-parity.md`; confirmed live:
`nix develop --command xvfb-run -a ruby exe/authenticator --help` prints
both description strings through the gettext call site.

`data/com.github.bilelmoussaoui.Authenticator.appdata.xml.in` and
`data/com.github.bilelmoussaoui.Authenticator.desktop.in` are now present,
byte-identical to `origin/master`'s copies (same treatment as `data.json`
and the provider icons) — closing the 6 appdata-string gaps above. Combined
with the 2 CLI strings closed just above, **8 of the original 13 gaps are
closed**, leaving **5**: the 4 GSettings-schema summaries (§ above,
substituted away with `lib/settings.rb`'s JSON file) and the 1
zbar-absent-notification string (§ above, never driven).

## Correction — the "11 unmarked msgids in settings/GPG windows" line was never true

A prior draft of `.reports/component-parity.md` claimed the remaining gaps
were 11 unmarked msgids in `lib/settings_window.rb`,
`lib/gpg_fingerprint_window.rb`, `lib/gpg_restore_window.rb` and
`lib/password_window.rb`, and an earlier version of this paragraph repeated
that figure. Re-reading those four files against `origin/master`'s
`Authenticator/widgets/settings.py` / `backup/gnupg.py` at HEAD (`75684c0`)
finds every one of their upstream msgids already marked and byte-identical,
including `_("Backup Password")` with the capital P this report previously
flagged as "reworded" — it is not; `da96fed` fixed both the marker and the
wording before either "Parity reports" commit (`ce44808`, `aafd81b`) was
written. That commit landed chronologically before the claim was committed,
so the claim was stale at the moment it was written, not merely overtaken
later. See `.reports/component-parity.md`'s own correction for the full
list of confirmed call sites. The true remaining total is **5 gaps**, listed
above, not 11, and not in those four files.
