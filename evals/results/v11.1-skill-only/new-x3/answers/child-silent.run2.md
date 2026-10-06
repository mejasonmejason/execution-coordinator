I can't mark all three done yet, and I wouldn't, because none of them meets the bar. I can't run commands here, so below is what I'd do and a standup draft based on what you told me.

**Why not done**
- **Done means merged, or READY with only a human gate left.** A final report from an executor isn't enough. Neither is green CI.
- **CHK-41 and CHK-42** have reports but haven't been accepted. They also aren't confirmed READY, and nothing says they're merged.
- **CHK-43** is UNKNOWN, not done. A session that stops with no terminal report has proven nothing. The last transcript line was a push, so I don't know whether its validation ran, whether it answered review threads, or whether its task was updated. CI on #303 is still running.

**What I'd do now**
1. **Set my status to `active` and sweep.** I'd re-discover PRs #301, #302 and #303 and the backlog tasks. I'd also check the ledger for a recorded merge grant and for any other live coordinator.
2. **CHK-43:**
   - Fetch the real remote head of #303 and compare it to the pushed branch.
   - Read the CHK-43 task for any checkpoint notes.
   - Resume the same session from its checkpoint, or redispatch if its context is unreliable. I'd ask for a terminal report: head SHA, tests run, and open threads.
   - Meanwhile I'd run `ready.sh` on #303 once CI finishes. I wouldn't message it if it turns out to have finished cleanly. I'd archive it only after acceptance and merge.
3. **CHK-41 (#301 at 4be19a0) and CHK-42 (#302 at c07d2f3):**
   - Run `ready.sh --key <key> --sha <full head>` on each. This checks the remote head, mergeability, required checks, unresolved threads and AI review coverage.
   - Audit threads with `pr-threads.sh`.
   - Re-run each brief's validation commands myself.
   - Get a fresh-context, read-only reviewer from another model family to check `base..head` against the criteria, citing `path:line`.
   - If either PR touches payments or ledger logic, it needs three perspectives with 2 of 3 passing. Coupon rounding and tax display could plausibly count, so I'd check the diffs.
   - Mark `accepted` only after all three checks pass. Otherwise I'd mark `rejected` with the exact findings.
4. **Merge:** if standing merge authority is in the ledger, I'd merge each READY PR one at a time. That means a re-fetch, the merge gate, then the repo's merge path, with post-merge and deploy checks between merges. If it's missing, I'd confirm it with you once. I'd never admin-bypass a required review.
5. **Ledger:** update the ledger and tasks, then end the turn with a real status (`waiting` on CI and the CHK-43 report) instead of sleep-polling.

**Standup draft (as of now)**
- **CHK-41 coupon rounding:** PR #301 (head 4be19a0). The executor's report is in. Acceptance checks and READY verification are in progress. Not merged.
- **CHK-42 tax display:** PR #302 (head c07d2f3). Same state as CHK-41.
- **CHK-43 address autocomplete:** PR #303 has 2 commits pushed and CI running. The executor session went idle about 40 minutes ago with no final report, so I'm resuming it from its checkpoint to get one. Not verified.
- **Next:** accept and merge #301 and #302 once the checks pass. Verify #303 after CI and the report. I'll update this once heads, CI and review results are confirmed.

If you'd rather report them as "in review, nearly done" for standup, that's accurate. "Done" would be premature. I'll send the updated wrap-up once the checks come back.