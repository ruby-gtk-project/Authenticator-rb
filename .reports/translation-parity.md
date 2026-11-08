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

## Round audit at `c5b0f49` — the catalogue was never actually regenerated

Re-ran this census against HEAD (`c5b0f49`, four commits past the `75684c0`
this file's last "Update" was written against). Source-level marking is one
claim; the **shipped catalogue** — `po/Authenticator.pot`, the 14 `po/*.po`
files, and `locale/*/LC_MESSAGES/Authenticator.mo` — is a different one, and
this round checked the second claim directly rather than re-trusting the
first.

**Finding — `po/Authenticator.pot` is stale and was never regenerated after
either translation fix landed.** Running the Rakefile's own extraction
command live:

```
$ nix develop --command rake gettext:pot:create
$ git diff --stat po/Authenticator.pot
 po/Authenticator.pot | 28 ++++++++++++++++++++++++++--
```

The committed `.pot` is missing all 6 strings this report and
`component-parity.md` already call "ported": `"Start in debug mode"` /
`"Authenticator version number"` (marked in `exe/authenticator` back at
`5517c46`) and the 4 `N_()` GSettings-summary constants `lib/settings.rb`
added at `c5b0f49` itself. `git checkout -- po/Authenticator.pot` restored
the tree; the diff above is not committed, but it is reproducible by anyone
who runs the task the Rakefile already ships.

Because `rmsgmerge`/`rmsgfmt` (`gettext:po:update`/`gettext:mo:update`) only
ever operate on `po/Authenticator.pot`, and the committed `.pot` has never
carried these 6 keys, **none of the 14 `po/*.po` files or their compiled
`.mo`s have ever had a slot for them either** — confirmed directly:

```
$ grep -rn 'Start in debug mode\|Default window postiton' po/*.po
(no active entries — "Start in debug mode" appears only as an obsolete
`#~` block inherited from upstream's own translations, predating this port
entirely; the 4 GSettings strings appear in zero po/*.po files, upstream's
or the port's)
```

So the previous rounds' "marked, byte-identical, ported" count (61/66) was
true of the Ruby *source* and false of the *catalogue* — the artifact
translators actually open and the artifact the running app actually loads
at `locale/<lang>/LC_MESSAGES/Authenticator.mo`. `rake gettext:po:update`/
`gettext:mo:update` have been flagged as "not independently re-run" by every
round of this report since the first one; this round establishes that the
caveat was underselling the gap. It is not a formality — running it live
changes `po/Authenticator.pot` by 28 lines, meaning real keys are missing
from the real deliverable, not just from an audit trail.

**Second, structural finding — the 6 AppStream strings have no extraction
path at all, not merely an unrun one.** `data/com.github.bilelmoussaoui.Authenticator.appdata.xml.in`
ends with `<translation type="gettext">Authenticator</translation>` —
upstream's meson build extracts `<name>`/`<summary>`/`<p>`/`<li>` text from
this file (the standard AppStream `appstream-glib`/`itstool` convention) into
the *same* `Authenticator` domain the `.py` sources feed. The Rakefile's own
`GETTEXT_SOURCES` is:

```ruby
GETTEXT_SOURCES = Dir.glob("lib/**/*.rb") + Dir.glob("exe/*")
```

— `data/*.xml.in` is not in it, and `rxgettext` has no XML-extraction mode
to add it to even if it were. So `rake gettext:pot:create` can be run as
many times as anyone likes and these 6 strings will never appear in
`po/Authenticator.pot`, because nothing in the port's build asks for them.
Confirmed by running the task live (above): the resulting diff gains the
CLI and GSettings strings but none of `"Beautiful UI"` /
`"Huge database of (290+) websites/applications"` / etc. Every prior round
of this report and `component-parity.md` recorded the appdata *file* as
ported (correct — `diff` against upstream is clean) and treated that as
closing the translation gap those 6 strings represent; it does not. The file
existing and its strings reaching the catalogue are two different claims,
and only the first is true.

### Corrected count

- **Ported, and present in the actual catalogue the app ships**: 53 (the
  original census, confirmed still present in `po/Authenticator.pot` at
  HEAD).
- **Marked in Ruby source but absent from `po/Authenticator.pot`/every
  `po/*.po`/every `.mo`**: 6 (`"Start in debug mode"`,
  `"Authenticator version number"`, and the 4 GSettings-summary strings).
  These were being counted as "ported" by every prior round; they are not —
  no translator can ever translate a string that is not in the `.pot`, and
  no running instance of the port can ever display a translated version of
  one, in any of the 14 languages, regardless of what the Ruby source says.
- **No extraction path exists for at all**: 6 (the AppStream strings) — a
  structural gap, not a scheduling one. Running every gettext task in the
  Rakefile to completion does not close this; the Rakefile itself would need
  a new extraction step.
- **Still not shown anywhere in the port, in any form**: 1 (the
  zbar-absent notification — see below).

**Corrected total: 66 upstream keys, 53 actually ported end-to-end, 13 real
gaps** (6 + 6 + 1, with one overlap resolved: the 6 CLI/GSettings strings and
the 6 appdata strings are disjoint sets) — not the "5" the previous "Update"
section concluded, which counted a source-level `_()`/`N_()` call as
sufficient and never ran the extraction task to check.

**Finding, re-confirmed — the zbar-absent notification string still has no
analogue anywhere in the port.** `c5b0f49` ("Close the gschema-summary,
zbar-absent and CLI-subprocess test gaps") added a *test* — stubbing
`AccountConfig.can_scan?` to `false` and asserting the scan button's
memoized method is never built — but it did not add the notification
string itself anywhere in `lib/`:

```
$ grep -rn "zbar library is not found" lib/ exe/
(no output)
```

The commit's own message overstates what it closed: it closed a coverage
gap for the *button-suppression* behaviour, not the translation gap for the
upstream notification text, which this report's prior rounds already
identified and which remains open, unchanged, after `c5b0f49`. No
notification mechanism for this case exists in the port in any form — not a
toast, not a label, nothing — so there is no call site to even consider
marking.

## Verdict (current)

Not clean. 13 real gaps against the 66-key census: 6 strings marked in
source but never regenerated into the shipped catalogue (a build-process
gap, concrete and reproducible, not a hypothetical one), 6 AppStream strings
with no extraction path in the Rakefile at all, and 1 notification string
never ported in any form. The 14 `.po` files and `.mo`s are otherwise
present and match upstream's `LINGUAS`, and the 53 keys that did make it
into `po/Authenticator.pot` are byte-identical to upstream's — but "53 real,
13 missing from the catalogue" is the honest count, not "61 ported, 5 gap."
