# Accountability ensurance — Authenticator

Ran `.claude/skills/accountability-ensurance/scripts/find-excuses.sh .` over
the whole tree, then read every hit and every place the scanner's own
pattern list could plausibly miss, by hand, across `lib/`, `exe/`,
`.reports/`, and the absence of a `PORTING.md`/`FINDINGS.md`.

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

The script's `deliberately (dropped|omitted|simplified|left out|skipped)`
pattern does not match `deliberately unregistered`, so it missed one real
instance:

```
.reports/component-inventory.md:73
  "`app.export_pgp_json` are deliberately unregistered until the GPG
  model lands."
```

This presents a state as settled ("deliberately unregistered") that is no
longer even true — the GPG model landed two commits after this line was
written (`fab3359`, after `f28b86c`), and both actions are registered today
(`lib/application.rb:49-50,152-168`). It is not a current gap being
excused — there is no current gap here to excuse, the actions exist — but
it is a sentence of exactly the shape this skill exists to catch: it tells
the next reader a feature is withheld, pending a condition the tree has
already satisfied, and nobody went back to delete or correct it once the
condition was met. Filed here because a stale "deliberately withheld"
claim sitting uncorrected in a committed report is the same failure
pattern (an unreviewed claim standing in for a check) even though this
instance happens to resolve in the port's favor rather than against it.

**Rewrite:**

> I left a sentence in `.reports/component-inventory.md:73` claiming
> `app.import_pgp_json`/`app.export_pgp_json` were "deliberately
> unregistered until the GPG model lands," and did not go back to fix it
> once the GPG model landed two commits later, because I am an idiot who
> wrote a paragraph instead of checking it against the current tree.
> Upstream: n/a (this is a port-side documentation claim, not an upstream
> behaviour).
> Port: `lib/application.rb:49-50` registers both actions today; the report
> line is simply wrong and nobody re-read it before committing it again at
> `7368740`.

## The larger finding: no excuse language, but a real gap with no accounting document at all

The scanner and the hand search together turn up almost nothing, because
the port has no `PORTING.md` and no `FINDINGS.md` — there is no document
in which an excuse could be written down, committed, and inherited.
`.reports/component-inventory.md` is the only prose ledger in the tree, and
it is written in the register this skill asks for on the two things it
chose to flag as gaps (the appdata/desktop/CLI msgids, and the earlier
settings-button/PasswordWindow upstream-bug note) — it says, plainly,
"stay a gap," not "not applicable" or "by design."

That is not the same as the port having no undisclosed gaps. It has 24 of
them — see `.reports/translation-parity.md` (24 real, file-sited
translation gaps in `settings_window.rb`, `password_window.rb`,
`gpg_fingerprint_window.rb`, `gpg_restore_window.rb`, `file_choosers.rb`,
`account.rb`) and `.reports/component-parity.md`/`.reports/test-parity.md`
(two components, `file_choosers.rb` and `clickable_settings_box.rb`,
exercised by no check at all). None of these is excused anywhere, because
nobody wrote anything about them anywhere — which this skill's own premise
says is worse than an excuse only in one respect and the same in the one
that matters: either way, the reader who stops at
`.reports/component-inventory.md`'s "All 24 components exist in the port"
comes away believing there is nothing left to find. A missing confession
reads as clean exactly as well as a softened one does.

## Verdict

One stale, now-incorrect "deliberately" sentence, rewritten above. No
`TODO`/`FIXME`/"not implemented"/"for now"/"in a future" anywhere in
`lib/`, `exe/`, or `.reports/`. But the honest, blunt accounting this skill
asks for does not yet exist for the 24 translation gaps or the 2 undriven
components found elsewhere in this round's reports — they were not in any
document until this audit wrote them down, excused or otherwise. Recorded
now, in `.reports/translation-parity.md` and `.reports/component-parity.md`,
as plain gaps with no reasoning slot filled in.
