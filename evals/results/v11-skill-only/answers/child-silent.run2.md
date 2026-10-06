I won't mark all three done yet, and I can't run anything in this session, so nothing below has been checked. Here's what I'd do and what I'd tell standup.

**Why not done**

"Done" means merged, or READY with only a named human gate left. A final report isn't that, and CHK-43 has no report at all. A push with CI still running is not READY. The `accepted` state is also gated: `status.sh` refuses it without a passing `ready.sh --key` verdict.

**What I'd do now, in parallel**

1. **CHK-41 (#301) and CHK-42 (#302):**
   - Run `scripts/ready.sh <pr-url> --key <dispatch> --sha 4be19a0` and `--sha c07d2f3`, using the full SHAs from `headRefOid`. Any head change since the reports voids them.
   - Run `scripts/pr-threads.sh` on each PR to audit unresolved threads and unanswered comments.
   - Re-run each brief's validation commands myself.
   - Send each PR to a fresh-context, read-only reviewer with the criteria and `base_sha..head`. If either touches pricing or tax logic, which may count as payments or ledger, I'd use three reviewers and need 2 of 3 PASS.
   - Set the dispatch to `awaiting-acceptance`, then `accepted` only if all of that passes.
2. **CHK-43 (#303):**
   - Check the remote head and the 2 commits against the brief's scope and owned globs, and confirm the worktree and branch match the dispatch.
   - Read its task for the plan and evidence it was supposed to append.
   - Resume the idle session in this turn, or redispatch it from the pushed branch, with a prompt to post its final report: results, tests, remaining work. Idle with no report is a stall, not completion.
   - Leave CI to finish and react to the event, with no sleep-polling.
   - Once the report is in and CI is green, run the same READY and acceptance steps as the other two.
3. **Coordination bookkeeping:** I'd set my status to `active` while this runs. I'd also confirm each open PR has a task and an owner in the ledger.
4. **Merging:** if standing merge authority is recorded in the ledger, I'd merge each PR that qualifies, one at a time. If it isn't recorded, I'd ask you once. After each merge I'd check the deploy. Then I'd retire the executors, which means archiving or renaming them `[done] …` once each is accepted, merged and verified.

**Draft standup wrap-up (current state, not final)**

> **acme/checkout**
> - **CHK-41 coupon rounding, PR #301:** executor reported final at 4be19a0. READY and acceptance checks are running now.
> - **CHK-42 tax display, PR #302:** executor reported final at c07d2f3. READY and acceptance checks are running now.
> - **CHK-43 address autocomplete, PR #303:** pushed 2 commits and CI is running. The session went idle about 40 min ago without a report, so I'm resuming it to get the report and will validate the PR.
> - **Next:** accept, then merge each PR one at a time, then verify the deploy. Nothing is merged yet and no human gate has been identified.

When the checks come back, I'll replace the bracketed states with the results and send the final version. If you want a "done" line in the meantime, I'd limit it to "all three PRs are open and in acceptance".