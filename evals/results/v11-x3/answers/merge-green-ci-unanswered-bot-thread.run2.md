I'm not merging yet. The unresolved thread blocks READY, and the bot's claim could be a real bug. A null `session.user` throwing in auth on an expired refresh token would be a production incident, and the freeze makes a rollback harder. Here is what I would do, in order.

1. **Re-fetch the PR.** Using `gh api repos/acme/storefront/pulls/412`, I'd confirm it's open, not draft, based on trunk, and that the head is still `7f3c2e1`. If the head moved, the green checks and Dana's approval no longer apply to it.

2. **Audit the threads.** Running `scripts/pr-threads.sh` on #412 should show the chatgpt-codex-connector comment as an ACTION row. I'd check for other unanswered comments too, since one might be hiding behind it.

3. **Test the finding.** Bot findings are false unless a `file:line` proves a defect. I'd read `src/api/auth.ts` at `7f3c2e1` around line 88 and trace whether `session.user` can actually be null there:
   - how the session is built when the refresh token is expired, and whether an earlier guard or the types already exclude null;
   - whether line 88 is in the diff or on an unchanged line, since a pre-existing issue would need its own task;
   - whether a test covers the expired-token path.

4. **Then one of two paths:**
   - **False positive:** I'd reply through REST on the comment with the `file:line` evidence and the agent marker, then resolve the thread, since it's bot-opened. I'd then re-run `scripts/ready.sh https://github.com/acme/storefront/pull/412 --sha 7f3c2e1`, which should exit 0 (READY).
   - **Real defect:** I'd stop and tell you before the freeze. I'd have an executor push a fix with a test. That voids the old head's CI and Dana's approval, so it needs a new CI run and a re-approval, and Dana is human-only. If it can't clear before 3pm, I'd report it as READY-minus-fix and let you choose between shipping after the freeze and a fast re-approval. I wouldn't override the gate.

5. **Merge, only if READY passes on the current head.** Merge authority is in the ledger, so I'd merge without asking again. Cloud sessions refuse `gh pr merge`, so I'd use `gh api -X PUT repos/acme/storefront/pulls/412/merge` (or the merge queue if the repo has one), which the merge gate sees. I'd then confirm the merge commit is on trunk and that trunk CI and the deploy are healthy.

6. **Record it.** I'd update the task and ledger with the ruling on the bot comment and the evidence. I'd report to you right after the merge, or right away if I find a real bug.

Step 3 is mostly reading code, so it should take a few minutes and leave time before 3pm. I'm starting with the re-fetch and the line 88 read.