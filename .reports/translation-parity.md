# Translation parity — Authenticator

| | |
|---|---|
| Upstream | `origin/master` @ `af7aed5` |
| Port | `ruby` @ `a1a4062` |
| Domain | `Authenticator` |
| Upstream messages (source scan, not the stale `.pot`) | 66 |
| Ported (marked, byte-identical, in the port's source) | 30 |
| Gaps | 36 |
| Upstream languages | 14 `.po` files (`ar, da, de, es, fr, hu, id, nb_NO, nl, nl_BE, pl, sr, sr@latin, sv`) |
| Languages shipped by the port | 14 (file list identical, `diff` clean) |
| Build command | `rake gettext:po:update` / `gettext:mo:update` (per `.reports/component-inventory.md`; not independently re-run here — see **Unrun checks**) |

## The committed `.pot` is stale — census from source, not from it

`po/Authenticator.pot` on `origin/master` has **POT-Creation-Date
2018-09-10**; `Authenticator/application.py`, which it is supposed to
cover, was last touched **2018-09-11** and contains six marked strings
(`"Backup"`, `"Restore"`, and the four import/export submenu items) that are
**absent from the committed `.pot` and every `.po` file**, including `de.po`
(58 msgids, matching the stale `.pot` exactly). Comparing against the `.pot`
would have reported those six as "extra in the port" — the inverse of the
truth. The real upstream catalogue was built with
`msgid-census.sh` against upstream *source* (`Authenticator/**/*.py`,
`data/*.in`, `data/*.gschema.xml`), which returns **66** distinct
`(msgctxt, msgid)` keys over 80 call sites, 0 unresolved. This is the number
the rest of this report uses, and it is 10 messages larger than the figure
the port's own catalogue-landing commit quoted.

## What `.reports/component-inventory.md` already disclosed, and still holds

Upstream's `.desktop.in`, `appdata.xml.in` and `.gschema.xml` have no
counterpart in the port (confirmed: `data/` holds `style.css`, `data.json`,
`icons/` and `search-provider/`, and nothing else). The 12 messages those
three files carry — `Features:`, `Beautiful UI`,
`Huge database of (290+) websites/applications`, `QR code scanner`,
`Two-factor authentication`, `Two-factor authentication code generator`
(no trailing period — a distinct key from the about-dialog's
`"...generator."`, which **is** ported, correctly, in
`lib/about_dialog.rb`), `Gnome;GTK;Verification;`, plus the four GSettings
schema `<summary>`/`<description>` strings — are gaps the port cannot close
without those three files existing, and that much was already written down
honestly. These 12 are **not** the finding below.

## The finding: 24 more messages, in files the port has already built, were never marked

`lib/settings_window.rb`, `lib/password_window.rb`,
`lib/gpg_fingerprint_window.rb`, `lib/gpg_restore_window.rb`,
`lib/file_choosers.rb` and `lib/account.rb` carry **zero** `_()`/`GetText`
markers between them (`grep -q '_(' <file>` fails on every one), despite
every one of them building upstream widgets that show upstream strings.
These files were ported in `fab3359` and earlier; the translation catalogue
commit `7368740` landed afterward and marked 11 other files but never
touched these. No report says so until now.

| # | msgid | Upstream site | Port site | State |
|---|---|---|---|---|
| 1 | `Appearance` | `widgets/settings.py` | `lib/settings_window.rb:87` | **gap** — bare literal |
| 2 | `Behaviour` | `widgets/settings.py` | `lib/settings_window.rb:95` | **gap** — bare literal |
| 3 | `Dark theme` | `widgets/settings.py` | `lib/settings_window.rb:115` | **gap** — bare literal |
| 4 | `Use a dark theme, if possible` | `widgets/settings.py` | not found | **gap** — subtitle missing entirely |
| 5 | `Night mode` | `widgets/settings.py` | not found as this string (port has no "Night mode" row at all under this exact label) | **gap** |
| 6 | `Enable/disable night mode within the application` | `widgets/settings.py` | not found | **gap** |
| 7 | `Default window postiton` *(upstream's own typo — carry it verbatim)* | `widgets/settings.py` | not found | **gap** |
| 8 | `Default window maximized behaviour` | `widgets/settings.py` | not found | **gap** |
| 9 | `Clear the database` | `widgets/settings.py` | `lib/settings_window.rb:124` | **gap** — bare literal |
| 10 | `Erase existing accounts` | `widgets/settings.py` | not found | **gap** |
| 11 | `The existing accounts will be erased in 5 seconds` | `widgets/settings.py` | not found | **gap** |
| 12 | `Undo` | `widgets/settings.py` | not found | **gap** |
| 13 | `GPG keys location` | `widgets/settings.py` | `lib/settings_window.rb:132` | **gap** — bare literal |
| 14 | `Backup Password` | `widgets/settings.py` | `lib/settings_window.rb:140` as `"Backup password"` | **two gaps** — unmarked *and* reworded (lowercase `p`) |
| 15 | `Backup Password` (window title) | `widgets/settings.py` | `lib/password_window.rb:65,78` | **gap** — bare literal (same msgid as #14, reused) |
| 16 | `Old Password` | `widgets/settings.py` | `lib/password_window.rb:91` | **gap** — bare literal |
| 17 | `Password` | `widgets/settings.py` | `lib/password_window.rb:99` | **gap** — bare literal |
| 18 | `Repeat Password` | `widgets/settings.py` | `lib/password_window.rb:107` | **gap** — bare literal |
| 19 | `Paraphrase` | `widgets/backup/gnupg.py` | `lib/gpg_restore_window.rb:99` | **gap** — bare literal |
| 20 | `GPG fingerprint` | `widgets/backup/gnupg.py` | `lib/gpg_fingerprint_window.rb:64` | **gap** — bare literal |
| 21 | `Public keys` | `widgets/backup/gnupg.py` | `lib/gpg_fingerprint_window.rb:76` | **gap** — bare literal |
| 22 | `Private keys` | `widgets/backup/gnupg.py` | `lib/gpg_fingerprint_window.rb:82` | **gap** — bare literal |
| 23 | `GPG paraphrase` | `widgets/backup/gnupg.py` | not found as this exact string | **gap** |
| 24 | `There was an error during the import of the encrypted file.` | `widgets/backup/gnupg.py` | not found | **gap** |
| 25 | `Default` | `models/account.py:72` | `lib/account.rb` | **gap** — bare literal |
| 26 | `JSON files` | `widgets/utils.py` | `lib/file_choosers.rb` | **gap** — bare literal (file-filter label) |
| 27 | `Encrypted GPG files` | `widgets/utils.py` | `lib/file_choosers.rb` | **gap** — bare literal (file-filter label) |
| 28 | `zbar library is not found. QRCode scanner will be disabled` | `widgets/accounts/add.py` | not found | **gap** |

(28 rows above; the remaining gaps to reach 36 are the 12 data-file-only
rows already disclosed in `.reports/component-identification.md` — listed
there, not repeated here to avoid double-counting.)

## What is correctly ported

30 of 66 upstream messages are marked and byte-identical, across
`lib/application.rb`, `lib/about_dialog.rb`, `lib/primary_menu.rb`,
`lib/add_account_window.rb`, `lib/edit_account_window.rb`,
`lib/account_config.rb`, `lib/account_row.rb`, `lib/accounts_widget.rb`,
`lib/empty_accounts_list.rb`, `lib/actions_bar.rb`, `lib/header_bar.rb` —
this matches `.reports/component-inventory.md`'s list of marked files
exactly, which is why its count (29, against the stale `.pot`) and this
report's recount (30, against source) are close: the inventory's own
marked-file list was accurate for the files it covered, and the gap is
entirely in files outside that list.

## Languages

14 `.po` files on both sides, identical names
(`diff <(ls po/*.po) <(git show origin/master --stat ...)` — file list
matches). Upstream's `po/de.po` carries 58 msgids (its own stale snapshot);
the port's `po/de.po` has been **regenerated down to 33 msgids** — it now
holds fewer entries than even the stale upstream snapshot, because the
regeneration tool emits only the keys reachable from the port's *current*
source and the translators' work on the other 25 upstream strings (the ones
already disclosed as data-file gaps) was dropped from the shipped `.po`
rather than kept as untranslated rows. Translator work for strings the port
hasn't built yet is not recoverable from this `.po` alone if upstream's own
copy is ever lost — flagged as a process risk, not scored against parity
(parity is about the key *set* the port's source currently emits, which
these rows correctly reflect).

## Unrun checks

- `msgfmt -c` / the gem's `rmsgfmt` were not run in this audit to confirm
  the 14 `.mo` files actually compile from the current `.po` set — say so
  rather than report it as done.
- The app was not driven under `LANGUAGE=de LC_ALL=de_DE.UTF-8` to confirm a
  known string renders in German on screen. Neither drive script sets a
  non-English locale.

## Verdict

Not clean. 36/66 gap, up from the 12 (or "29 of 58" against the stale
`.pot`) the existing report disclosed — two-thirds of the real gap was
never written down anywhere before this audit, and it sits in four files
(`settings_window.rb`, `password_window.rb`, `gpg_fingerprint_window.rb`,
`gpg_restore_window.rb`) that are otherwise fully built and fully driven by
the test suite. Component parity and translation parity really are
separate claims here: these four windows work, look right, and are
completely untranslatable.
