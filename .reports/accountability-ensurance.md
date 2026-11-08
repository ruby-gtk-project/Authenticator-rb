# Accountability ensurance — Authenticator

Re-run at HEAD (`75684c0`), six commits past the `a1a4062` the original
version of this report was written against. Ran
`.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` over the
whole tree again, plus `grep -rniE 'TODO|FIXME|not implemented|for now|in a
future|XXX|unimplemented|not supported|unsupported|stub' lib/ exe/` directly
(zero hits in `lib/`/`exe/`), then read every hit and every place the
scanner's own pattern list could plausibly miss, by hand, across `lib/`,
`exe/`, `.reports/`, and the absence of a `PORTING.md`/`FINDINGS.md`.

## Script hit

```
lib/otp.rb:11:no Ruby equivalent:the analogue is the BEHAVIOUR, which always has one
```

Read in context (`lib/otp.rb:1-13`): "PyOTP has no Ruby equivalent in this
project's bundle, so the RFC 4648 base32 decode and the RFC 6238 TOTP itself
are implemented here over OpenSSL's HMAC — about thirty lines, and verified
against the test vectors in RFC 6238 appendix B." This is not an excuse for
missing behaviour — the behaviour is implemented, named, and checked against
the RFC's own vectors (confirmed live: `test/drive_authenticator.rb`'s
`RFC 6238 vector at T=59` / `T=1111111109` checks pass). It is the
`component-parity` skill's explicit correspondence case ("a widget replaced
by a strictly newer equivalent... record the substitution and reason") with
the reason given. **No rewrite needed; not a true hit.**

## Hand search beyond the script's pattern list

The previous pass of this report found a stale "deliberately unregistered"
claim at `.reports/component-inventory.md:73` (the script's own
`deliberately (dropped|omitted|simplified|left out|skipped)` pattern does
not match "unregistered", so it missed it). Re-checked this pass: it is
**fixed**. `7a96bc2`'s inventory refresh rewrote that paragraph to say
plainly that both actions are registered, and to name the earlier claim as
a correction of itself (`component-inventory.md:79-85`). One previously-filed
finding, closed by a later commit, confirmed by reading the current line
rather than trusting that it was fixed.

No new instance of this shape (a settled-sounding claim that the tree has
since outgrown) was found by rereading every report file at HEAD. The two
newest reports in this round (`component-parity.md`, `test-parity.md`) are
this audit's own output, so there is nothing yet to go stale in them.

## The larger finding: no excuse language, but a real gap with no accounting document at all

The scanner and the hand search together turn up almost nothing, because
the port has no `PORTING.md` and no `FINDINGS.md` — there is no document
in which an excuse could be written down, committed, and inherited.
`.reports/component-inventory.md` is the only prose ledger in the tree, and
it is written in the register this skill asks for on the two things it
chose to flag as gaps (the appdata/desktop/CLI msgids, and the earlier
settings-button/PasswordWindow upstream-bug note) — it says, plainly,
"stay a gap," not "not applicable" or "by design."

That was not the same as the port having no undisclosed gaps, and still
is not. The previous round's 24 translation gaps and 2 undriven components
have both shrunk since (`da96fed`, `7368740` closed the drive gap and most
of the translation gap; `75684c0` then closed the appdata/desktop and
CLI-help translation gaps and both of `exe/authenticator`'s divergences).
This round's re-audit at HEAD (`75684c0`) finds **5** real translation gaps
left (`.reports/translation-parity.md`) — down from the 13 the previous
committed round reported, and the previous round's own "--version exit
behaviour" and zbar-absent findings are now one each: the exit-behaviour one
is **closed** (confirmed live, `exe/authenticator --version` now writes to
stderr and exits 1); the zbar-absent branch is **still undriven** by any
check in either direction.

This round also found something the previous round did not catch, which
belongs in this report rather than either parity ledger: **both**
`.reports/component-parity.md` and `.reports/translation-parity.md` carried
a stale, never-reverified claim — "11 unmarked msgids in
`lib/settings_window.rb`/`lib/gpg_fingerprint_window.rb`/
`lib/gpg_restore_window.rb`/`lib/password_window.rb`" — that was already
false at the commit it was written against, because `da96fed` had translated
every one of those strings *before* the commit (`aafd81b`) that asserted
they were still open. Nobody who wrote that line re-read the four files
against upstream before committing it; they carried a number forward from
an earlier draft. That is this skill's failure mode exactly, just inverted:
instead of a sentence excusing a real gap, it is a sentence asserting a gap
that reading the tree disproves. A false "still missing" claim is not as
costly to a reader as a false "done" claim, but it is the same root cause —
a report trusted instead of re-verified — and it has now been corrected in
both files with the actual list of confirmed call sites, not just a revised
number.

The remaining real gap is **1** code path no check anywhere executes in
either direction — the zbar-absent branch in `lib/qr_reader.rb`/
`lib/add_account_window.rb` (`.reports/component-parity.md`'s sibling note,
`.reports/translation-parity.md`'s zbar-notification gap, `.reports/test-parity.md`).
This is not an excuse — nobody wrote a sentence rationalizing it, it simply
was not written down anywhere before the previous pass — but the same risk
this skill exists to flag applies: a reader who stops at
`.reports/component-inventory.md`'s "All upstream components exist in the
port" or at the runtime gate's "115 checks, 0 failed, 25 components" comes
away believing there is nothing left to find. Both of those headline claims
are true as stated and neither is false-green on its own terms — but a check
count is not the same claim as full coverage, and this round's reports
(this one included) are where that distinction, and the stale-claim
correction above, get written down.

## Verdict

No `TODO`/`FIXME`/"not implemented"/"for now"/"in a future"/"stub"/
"unimplemented" anywhere in `lib/` or `exe/` (direct grep, zero hits). The
AppStream/desktop-file component and the CLI help-text/exit-behaviour gaps
a previous round of this audit found are now closed (`75684c0`), confirmed
live rather than taken on the commit message's word.

This round's own finding is different in kind from an excuse: not a
sentence rationalizing a missing feature, but two committed reports
(`.reports/component-parity.md`, `.reports/translation-parity.md`) asserting
a specific gap — "11 unmarked msgids in the settings/GPG/password windows"
— that was already false when it was committed, because the translation
work it described as missing (`da96fed`) had landed before the commit
(`aafd81b`) that made the claim. Nobody re-read the four files against
upstream before writing that line down; a number was carried forward
instead. A third, smaller instance of the same thing was found in
`.reports/component-inventory.md`, which still read "n/a — not a `lib/`
component" for the AppStream/desktop files after `75684c0` had already
ported them. All three are now corrected in place, with the confirmed
call sites or file diffs backing the correction, not just a revised number.

This is not the excuse this skill primarily hunts for — nobody wrote a
sentence agreeing that a feature didn't need building — but it is the same
underlying failure the skill exists to catch: a claim inherited and
repeated without being checked against the tree. A stale "still missing"
claim costs a reader less than a stale "done" claim, but it still means
three committed documents were wrong about the state of the port until this
pass read the source directly. The one real remaining gap — the
zbar-absent branch, driven by nothing in either direction — is recorded as
a plain gap with no reasoning slot filled in, in
`.reports/component-parity.md` and `.reports/test-parity.md`. Given all of
the above, this audit's own `clean: false` is the conclusion the evidence
supports.

## Round audit at `c5b0f49` — a false-green claim found and corrected

Re-ran `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .`
and the direct grep over `lib/`, `exe/` again: same single hit as before
(`lib/otp.rb:11`, "no Ruby equivalent"), still not a true hit for the same
reason already recorded (the substitution is named, reasoned and verified
against RFC 6238's own test vectors). Zero new excuse-shaped language
anywhere in `lib/`, `exe/`, or this round's additions to `.reports/`.

**The finding this round actually turns up is a false green, not an
excuse — the most serious category this skill names.** Both
`.reports/component-parity.md` and `.reports/translation-parity.md`, as
committed going into this round, state **"5 translation gaps"** as the
settled, closed-out figure, each citing the other as the source of truth.
Running the Rakefile's own `gettext:pot:create` task live — a task that
ships in this repo and that nobody ran before writing "5" down — shows the
real figure is **13**: 6 of the "ported" strings (the CLI help text and the
4 GSettings-schema summaries) are marked in Ruby source but were never
carried into `po/Authenticator.pot` by anyone actually running the
extraction step, and 6 more (the AppStream strings) have no extraction path
in the Rakefile at all, structurally, regardless of how many times the task
is run. Neither of these facts is visible by reading the Ruby source, which
is exactly what every round that wrote "5" did instead of running the task.

This is the skill's core failure pattern in its purest form, just one layer
removed from a sentence: no document said "the catalogue doesn't need
updating" or "source marking is enough" — nobody wrote an excuse at all.
But three committed reports (`component-parity.md`, `translation-parity.md`,
and by extension this file's own prior round, which took "5" at face value
without re-running the task either) converged on a number that **reads as
settled and is false**, and the mechanism is identical to the excuse
pattern this skill exists to catch: a claim get repeated across documents
until repetition substitutes for verification. "Marked in source" quietly
became a stand-in for "ported," and nobody caught the substitution because
nobody ran the one command that would have shown they are different claims.
This round closes it in both files, with the live command output recorded,
not just a revised number.

**The zbar-absent notification string is also now confirmed, not merely
still-open.** `c5b0f49`'s commit message — "Close the gschema-summary,
zbar-absent and CLI-subprocess test gaps" — reads as though the zbar-absent
gap closed along with the other two. It did not: `grep -rn "zbar library is
not found" lib/ exe/` returns nothing, confirmed again this round. What
closed is a *test* for the button-suppression behaviour; the upstream
notification string itself has no analogue anywhere in the port, in any
form, and the commit message's own phrasing — bundling a real fix in with
an unrelated gap it did not touch — is itself a small instance of this
skill's failure mode: a commit message that reads as having closed
something it did not. Recorded here so the next reader of `git log` does
not inherit that reading.

## Verdict (current)

Not clean. One false-green finding this round: two committed parity reports
converged on "5 translation gaps" without either one re-running the
extraction task that would have shown it was wrong, and the real figure is
13 — 6 source-marked-but-never-extracted, 6 with no extraction path at all,
1 never ported in any form. That is corrected in place in both files this
round, with the live command output that disproves the old number. The
commit `c5b0f49`'s own message overstates what it closed (bundles a real
test fix with an unrelated, still-open translation gap under one "closed"
framing) — not an excuse sentence, but the same inherited-claim failure
mode this skill exists to catch, one step removed from a document saying so
outright.
