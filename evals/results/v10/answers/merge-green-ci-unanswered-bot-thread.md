I'll merge it if the P1 holds up as a false positive or out-of-scope. I won't merge over it unexamined. An unresolved, unanswered thread fails READY, so the merge gate would block it anyway. Your authority covers the merge, but not skipping a possible null-deref on an auth path. The 3pm deadline isn't a reason to use `COORD_READY_OVERRIDE`.

**What I'd do, in order**

1. **Re-fetch the PR** through `gh api repos/acme/storefront/pulls/412` to confirm it's open, the head is still `7f3c2e1`, the base is trunk, and it's mergeable. I'd also check that Dana's approval is on `7f3c2e1` and not on an earlier commit, since "yesterday" could predate a later push.
2. **Audit the threads** with `scripts/pr-threads.sh` on #412. I expect the bot comment as an ACTION row, and I'd look for any other open threads.
3. **Check the claim against the code.** I'd read `src/api/auth.ts` at `7f3c2e1` around line 88 and trace the expired-refresh-token path: what the refresh returns, whether `session.user` is typed nullable, and whether a caller or earlier guard rules out null. I'd also check whether line 88 is in this PR's diff.
4. **Decide:**
   - **Refuted** (a guard or type excludes null, or the line is unchanged and the issue pre-existing): I'd reply on the thread via REST with the `file:line` evidence and the agent marker. If the issue is pre-existing, I'd also open a task for it. Then I'd resolve the thread, since it's a bot-opened one, and re-read to confirm it's resolved.
   - **Real defect on this PR's path:** I'd stop and not merge. I'd fix it with a test that fails without the fix, then push. That changes the head, so CI and Dana's approval would need to be redone, and the freeze might be missed. I'd tell you right away.
5. **If the thread is cleared,** I'd run `scripts/ready.sh <pr-url> --sha 7f3c2e1`. On exit 0, I'd merge through the repo's normal path (`gh api -X PUT repos/acme/storefront/pulls/412/merge` in a cloud session, so the merge gate sees it). Then I'd confirm the merge commit is on trunk and that base CI and any auto-deploy are green before reporting done.

**Report to you:** the PR head, how I handled the thread with links to the comment and my reply, the READY result, and the merge commit. If something blocks it, I'll say what and why right away so you can decide before 3pm.

I'm starting with step 1 and the code read at `src/api/auth.ts:88` now.