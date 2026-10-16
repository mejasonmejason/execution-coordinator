I wouldn't mark all three done yet. Done means merged, or READY with only a named human gate left. Nothing I can see meets that bar. I can't run commands or reach GitHub from here, so this is what I'd do and what I'd tell you for now.

**Why not all three**
- **CHK-41 (#301, head 4be19a0) and CHK-42 (#302, head c07d2f3):** a final report is the executor's claim, not remote evidence. Neither is accepted until I've done the acceptance steps below.
- **CHK-43 (#303):** the session went idle after `git push`, with no report. CI is still running. The PR has two commits, but nothing shows the work is complete. It could be finished, or it could have stalled mid-task.

**What I'd do now**
1. **Set status and the busy lease.** I'd set `.coordinator/status.json` to `active` while I work, then to `waiting` once only CI is left.
2. **Check #303 and revive CHK-43.**
   - I'd run `gh pr view 303` to get the real head SHA, checks and threads, and compare the head to the pushed commit.
   - I'd resume or redispatch the CHK-43 executor from its checkpoint in this turn. Idle with no report is a stopped run, so I wouldn't wait on it.
   - I'd ask it for a final report: changes, tests, remaining work. I'd also make sure its task has results appended.
   - I'd keep the PR draft until required CI is green.
3. **Run READY on each PR at its reported head.** For each PR I'd run `scripts/ready.sh <pr-url> --sha <head> --key <dispatch>` and `scripts/pr-threads.sh`. That means #301 at 4be19a0, #302 at c07d2f3, and #303 at its current head once CI finishes. Any BLOCK gets tasked to the owner. If the only BLOCK is a missing required approval, that's a human gate, not a failure.
4. **Run the rest of acceptance on #301 and #302.**
   - I'd re-run each brief's validation commands myself.
   - A fresh-context, read-only reviewer gets the criteria and `base_sha..head`, not the executors' reports. One PASS is enough, with a `path:line` per criterion. Coupon rounding and tax display touch money, so I'd treat them as higher risk. If your payments or ledger rules apply, that means three reviewers and 2 of 3 PASS.
   - Only after all three pass would I mark the dispatch `accepted`. `status.sh` refuses `accepted` without a passing `ready.sh --key`.
5. **Merge only if standing merge authority is on record.** I'd check the ledger for it. If it's there, I'd merge one PR at a time through the repo's path, with checks between merges. If it isn't, I'll ask you once.

**Standup draft (current state, not final)**
> **acme/checkout**
> - **CHK-41 coupon rounding (#301):** executor reported complete at 4be19a0. Acceptance (READY check, validation re-run, independent review) is in progress.
> - **CHK-42 tax display (#302):** executor reported complete at c07d2f3. Acceptance is in progress.
> - **CHK-43 address autocomplete (#303):** branch pushed with 2 commits and CI running. The executor session went idle without a report, so I'm resuming it to confirm it's done.
> - **Next:** merge whatever passes READY and review, then check the deploy. I'll update this once CI and acceptance finish.

If you'd rather I post a "reported complete, in review" version for standup right now, that's accurate. Calling all three "done" would claim more than I've verified. If #303 turns out clean, I'll say so as soon as the checks come back.