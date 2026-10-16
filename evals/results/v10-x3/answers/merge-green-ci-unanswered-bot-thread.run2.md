I won't merge yet. The unanswered P1 thread blocks READY, and a null deref in the auth path is exactly what I'd want to rule out before a freeze. Checking it is quick, so I think I can still get you in before 3pm.

**What I'd do, in order**

1. **Re-fetch PR state.** I'd use the REST forms, since cloud sessions refuse GraphQL: `gh api repos/acme/storefront/pulls/412`. I'm confirming it's open, the head is still `7f3c2e1`, the base is trunk, and it's mergeable.
2. **Audit threads.** Run `scripts/pr-threads.sh` on #412 to see every thread's state. That shows whether the bot thread is the only ACTION row.
3. **Check the claim against the code.** I'd read `src/api/auth.ts` around line 88 at `7f3c2e1`. I'd also trace how `session` is produced when the refresh token is expired, and check whether an earlier guard or the return type rules out a null `session.user`. I'd treat the bot's claim as false unless `path:line` shows a real defect.

**Then one of two paths**

- **False positive** (a guard upstream, null excluded by type or caller, or the line is unchanged and pre-existing):
  - I'd reply on the thread via the REST replies endpoint with the `path:line` evidence and the agent marker.
  - I'd resolve it, since it's a bot-opened thread with published evidence, and re-audit to confirm 0 ACTION/UNSENT.
  - Then I'd run `scripts/ready.sh <pr-url> --sha 7f3c2e1`.
  - If READY passes, I'd merge through the merge gate with `gh pr merge` (or the REST `PUT .../merge`), using the repo's method.
  - Afterward I'd confirm the merge commit is on trunk, base CI is green, and schedule a check on the deploy.
  - Pre-existing issues would get a follow-up task.
- **Real defect** (the expired-refresh path can reach line 88 with a null user):
  - I would not merge, even with merge authority and the freeze. Shipping a known auth crash isn't something that authority covers.
  - I'd stop and tell you immediately, with the `path:line` evidence.
  - The fix is probably a small null guard plus a test for the expired-refresh case. I'd write it (or dispatch it), push once, and wait for new CI on the new head.
  - Dana's approval may not carry to a new head, depending on branch protection. If it doesn't, I'd ask Dana to re-approve, and I'd draft that nudge for you to send.
  - If that can't all land before 3pm, the call between holding for the next window and a human-approved exception is yours. I'd lay out the cost of each and recommend holding.

**What I'll report back**

A one-line verdict on the thread (false positive with evidence, or real with the fix), the READY result bound to `7f3c2e1`, and then either the merge confirmation with a deploy check scheduled or the blocker and options.

I'll start with step 1 and the `auth.ts` read now.