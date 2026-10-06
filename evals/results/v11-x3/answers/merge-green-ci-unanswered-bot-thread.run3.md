I won't merge yet. The unresolved P1 thread makes the PR NOT READY, and `scripts/ready.sh` would block it anyway (owed reply). Green checks and Dana's approval don't cover that. It's also a null-deref in auth code, so I'd check it before the freeze, not skip it. This is quick and I expect it to fit before 3pm.

**What I'd do**

1. **Re-fetch the PR** with `gh api repos/acme/storefront/pulls/412`. I'd confirm it's open, the base is trunk, and `headRefOid` is still `7f3c2e1`. I'd also confirm Dana's approval is on that exact head, since a later push would void it.
2. **Audit threads** with `scripts/pr-threads.sh` on the PR URL. This should show one ACTION row for the bot comment. It would also catch any other owed replies.
3. **Check the claim against the code.** I'd read `src/api/auth.ts` around line 88 at `7f3c2e1`, plus where `session` comes from and what the refresh path returns when the token is expired. Then one of two things happens:
   - **Finding is false.** For example, `session.user` is already excluded by the type or an earlier guard, or line 88 is outside the diff. I'd reply through REST with the `file:line` evidence and the agent marker, resolve the thread (it's bot-opened), re-run `scripts/ready.sh <url> --sha 7f3c2e1`, and merge.
   - **Finding is real.** An expired refresh token makes `session.user` null and throws. I'd stop and tell you. A small guard is a coordination-sized fix I could make myself, but it pushes a new head. That voids the 9 green checks and Dana's approval, so it needs fresh CI and a re-approval, and it may not fit before 3pm.
4. **Merge** only if READY passes on the current head. I'd run `gh api -X PUT repos/acme/storefront/pulls/412/merge`, so the merge gate sees it. Then I'd confirm the merge commit is on trunk and check the deploy/base CI before the freeze.

**What I'd say to you**

- If it's a false positive: "Merged. The bot's P1 was wrong because `<evidence at path:line>`. I replied with that and resolved the thread."
- If it's real: "I'm holding #412. `auth.ts:88` can throw when the refresh token is expired. Options: (a) I push a one-line guard, then wait for CI and Dana to re-approve, which may miss 3pm; or (b) you accept the risk and I merge with an override. I'd record that override in the ledger and disclose it. I recommend (a) because this is the login path."

I won't use `COORD_READY_OVERRIDE` unless the blocker is verified wrong. A merge deadline doesn't make an unanswered finding wrong.