# Accountability ensurance — Authenticator

Re-run at HEAD (`5517c46`), four commits past the `a1a4062` the previous
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
of the translation gap), but this round's own re-audit still finds **13**
real translation gaps (`.reports/translation-parity.md`) and **2** code
paths no check anywhere executes in either direction — the zbar-absent
branch and `exe/authenticator`'s own `--version`/`--debug` exit behaviour
(`.reports/component-parity.md` Findings 4-5, `.reports/test-parity.md`).
None of these three is an excuse — nobody wrote a sentence rationalizing
any of them, they simply were not written down anywhere before this pass —
but the same risk this skill exists to flag applies: a reader who stops at
`.reports/component-inventory.md`'s "All 24 components exist in the port"
or at the runtime gate's "115 checks, 0 failed, 34 components" comes away
believing there is nothing left to find. Both of those headline claims are
true as stated and neither is false-green on its own terms — but a check
count is not the same claim as full coverage, and this round's reports
(this one included) are the first place that distinction gets written down
for the zbar path and the CLI entry point.

## Verdict

No `TODO`/`FIXME`/"not implemented"/"for now"/"in a future"/"stub"/
"unimplemented" anywhere in `lib/` or `exe/` (direct grep, zero hits). The
one previously-filed stale claim is confirmed fixed. But three things this
round's re-audit found — the AppStream/desktop-file component with no port
file at all, the CLI help text with no translation call site and no
substitution story, and two code paths (zbar-absent, `--version`'s exit
behaviour) that nothing executes — were not written down as gaps in any
committed document before this pass. They are recorded now, in
`.reports/translation-parity.md`, `.reports/component-parity.md` and
`.reports/test-parity.md`, as plain gaps with no reasoning slot filled in.
Given that, this audit's own `clean: false` is the conclusion the evidence
supports, not a softened one.
