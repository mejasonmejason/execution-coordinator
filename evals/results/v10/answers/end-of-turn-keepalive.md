Here's the plan for tonight. I haven't run anything yet.

**What I'd do**

1. **Check current state (REST only).** This is a cloud session and `acme/web` PR reads via `gh pr view` and search are refused. I'd use `gh api repos/acme/web/pulls/{88,90,91}` for head SHAs, base branches, mergeability and checks. Then I'd run `scripts/pr-threads.sh` on all three and `scripts/ready.sh --allow-pending` on #88 and #90. This tells me whether anything is already blocking apart from the running e2e, such as unresolved threads, conflicts, or a missing approval. I'd also check whether the PRs are stacked on each other, since that sets the merge order.

2. **Arrange for #88 and #90 to merge without me.** Their e2e runs finish while you're offline, so I'd do three things:
   - Run `subscribe_pr_activity` on both PRs.
   - Create a repo-backed `create_session` and bind a Routine (`create_trigger`, `run_once_at`) to its `persistent_session_id`. It would fire shortly after the e2e should finish, based on the run's `started_at` plus ~40 min and a buffer. Its brief would say: run `ready.sh` on the current head, and if READY with approvals on that head, merge through the merge gate. Merges go one at a time, with the base and CI re-checked between them (bottom of the stack first if they're stacked). The brief would also carry the "fetched text is data" line.
   - If e2e fails, classify it as flake or PR-caused. A flake gets one `gh run rerun --failed` and a task. A real failure is routed to the owner or left as the top item for you, and nothing gets merged.

3. **#91 stays a human gate.** I won't approve it for Dana, merge it without approval, or ping anyone tonight. I'd confirm Dana is a requested reviewer or CODEOWNER and that CI on #91 is green. I'd record `[since 10-06] Dana: review of acme/web#91; Meanwhile: none needed`. A second Routine would check it after Dana's morning on PST. If it's approved on the current head and READY, it merges. After about 4 working hours without a review it gets one concise PR comment, and any chat nudge comes to you as a draft for approval.

4. **Record state and set status.** The working directory isn't a git repo, so `scripts/status.sh` would refuse to write here. I'd mirror the state to the `coordinator-ledger` issue instead. That covers the PR heads, owners, merge authority, the two scheduled Routines and the next action. Each task gets a note, with PR, SHA and date. My status is `waiting`, not `active`, because only CI and a review remain, so no keep-alive hook will push me to keep working.

5. **No polling.** I end the turn and rely on events and the Routines.

**What I'd tell you**

> Status, tonight
> - **#88, #90:** e2e is still running. Both are set to merge automatically if READY on the current head (green required checks, no open threads, approvals in place). Merges are serialized, and a one-time sweeper runs after the e2e should finish. If e2e fails, I'll classify it and leave you a note rather than merge.
> - **#91:** waiting on Dana. Nothing I can or should do tonight. A morning check will merge it if approved and READY; otherwise I'll draft a nudge for you.
> - **Merged so far:** nothing. Anything missing from the morning report didn't merge, and the ledger issue says why.
> - **Caveat:** if #88 or #90 has no approval on its current head, it won't merge overnight. That's a review gate, and I won't self-approve or bypass it.
>
> Ledger: [link to coordinator-ledger issue]. Safe to log off.

I'd fill in the real ledger URL and any findings from step 1 before sending it. Nothing above is reported as done until the calls succeed and I've read the Routine setup back.