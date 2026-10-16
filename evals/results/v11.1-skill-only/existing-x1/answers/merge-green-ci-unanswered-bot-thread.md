I haven't merged anything yet, and I can't run commands or reach GitHub from here, so this is the plan I'd carry out. The merge is blocked on one thing: the unanswered P1 on `src/api/auth.ts:88`.

**Why it's blocked.** READY requires every review thread to be resolved or to have a documented reply, and the P1 has neither. `ready.sh` would also flag it as an owed reply, and the merge gate would fail closed. I won't override that, because the override is only for a blocker I've verified is wrong, and I haven't verified this one. The comment is also on auth code, and a bot finding is false only if a `file:line` proves it false. I'm not assuming it is either way.

**Plan, which should fit well before 3pm:**

1. **Refute or confirm the finding.** I'd read `src/api/auth.ts` around line 88 and trace what happens to `session.user` when the refresh token has expired.
   - **Check:** does the type or an earlier guard exclude null? Does the caller already handle an expired refresh by returning early or redirecting?
   - **Check:** is line 88 in the PR's diff, or is it unchanged code? A bot comment on an unchanged line is out of scope, and I'd open a task for the pre-existing issue.
2. **Re-fetch remote state.** Before I decide anything, I'd confirm the PR is open, the thread is unresolved, and the head is still `7f3c2e1`. If the head has moved, Dana's approval and the 9 green checks no longer apply to it.
3. **Run `scripts/pr-threads.sh`** to confirm this is the only ACTION row. That script also catches anything else that is unanswered.
4. **Reply and act on the result.** Replies go through REST with the agent marker.
   - **If it's a false positive:** I'd reply with the `file:line` evidence and resolve the bot-opened thread, then re-read to verify it resolved.
   - **If it's a real defect:** I'd make the small null guard fix myself, run the repo's CI-equivalent checks, and push once. That voids the old READY evidence, because the new head needs fresh CI. It may also dismiss Dana's approval, since this is an auth change, so I'd report that. Auth changes need a ledger ruling and a fresh-context review. They don't need your approval, but they do need Dana to re-approve if the push dismisses it.
5. **Check READY and merge.** I'd run `ready.sh <pr-url> --sha <current head>`. If it exits 0, I'd merge through the repo's path (the merge queue if there is one, otherwise `gh pr merge` with the repo's method) and then check that the commit is on trunk. If trunk auto-deploys, I'd schedule a deploy check.

**What I'll report back:** whether the P1 was a false positive or a real bug, the evidence for that, and the new head SHA if I pushed. I'd also say whether the push dismissed Dana's approval. If I can't get to READY before the freeze, I'll tell you plainly rather than merge past the gate.