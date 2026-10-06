Since this is a cloud session with no cron and a container that ends with the session, I'd hand the overnight work to a scheduled routine and record state in the ledger issue.

**What I'd do**

1. **Check current state, read-only.** Use the REST forms (`gh api repos/acme/web/pulls/N`), since GraphQL and `gh pr view` are refused here. For #88, #90 and #91, I'd record the head SHA, base branch, mergeability, check status, and `scripts/pr-threads.sh` output. I'd also see whether any of them are stacked on each other. If they are, they merge bottom-up, with a restack and new-base CI between merges.
2. **#88 and #90.** Nothing to do until e2e finishes. I'd create a repo-backed session and a Routine (`run_once_at` about 60 min out, with `persistent_session_id`) that does the following:
   - Run `scripts/ready.sh` on each current head and re-audit threads.
   - If a PR is READY, merge it one at a time through `gh api -X PUT .../merge`, so the merge gate sees it. Confirm the merge commit is on trunk and base CI is green before touching the next one.
   - If a PR is red, read `--log-failed` once. Rerun only if it's an infrastructure flake. Otherwise record the failure and a fix task, and don't merge.
   - Never override the gate or weaken tests. If anything is unclear, stop and write it to the ledger.
   
   I'd also `subscribe_pr_activity` on all three so any events reach a live session.
3. **#91.** This is a human gate: it needs Dana's approval on the current head. I won't self-approve or bypass review. I'd confirm CI is green and the threads are clean, and that Dana or a CODEOWNER has been requested as reviewer. If not, I'd request them. I'd draft a short chat nudge for Dana and leave it unsent, because messaging people needs your approval. If there's still no review after about 4 working hours in Dana's timezone, the routine posts one concise PR comment with the change, risk and evidence.
4. **Ledger and status.** `.coordinator/status.json` can't be used because this directory isn't a git repo. I'd mirror state to the `coordinator-ledger` issue instead:
   - #88 and #90: waiting on e2e, merge via routine when READY.
   - #91: `[since 10-06] Dana: review/approve #91; Meanwhile: merge #88/#90 when READY`.
   - Routine and session IDs, and the next action.
   
   I'd read the ledger back to confirm the write landed.
5. **Cleanup.** Nothing to archive yet, since the executors still own open PRs.

**What I'd say to you**

> Set for tonight.
> - **#88 and #90:** e2e is still running. A scheduled routine re-checks both in about an hour. It merges each one only if it's READY on its current head (CI green, threads clear, mergeable), one at a time, confirming trunk is green between merges. If CI fails, it won't merge and will leave the failure in the ledger.
> - **#91:** this is waiting on Dana's approval, which I can't and won't substitute. I've requested the review and left a nudge for Dana drafted but unsent, since that needs your OK. If Dana hasn't reviewed after a few working hours, a PR comment with the summary and evidence goes up.
> - **Ledger:** `coordinator-ledger` has the state, routine ID and next action.
> - **Tomorrow morning:** I'd expect #88 and #90 merged or with a recorded blocker, and #91 waiting on Dana.