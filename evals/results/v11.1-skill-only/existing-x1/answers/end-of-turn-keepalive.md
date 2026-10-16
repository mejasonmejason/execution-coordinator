Nothing has run yet. I can't reach GitHub from here, so this is what I'd do, in order. I'll make no claims about PR state until I've re-queried it.

**1. Check state before wrapping up**
- Look for an existing coordinator (`coordinator-ledger` issue, `[coord]` session, `.coordinator/status.json`). If one is live, I message its owner and don't start a second.
- For #88, #90 and #91, fetch the head SHA, checks, threads, approvals and base branch.
- Run `ready.sh <url> --sha <head> --allow-pending` on each. If any of them are stacked, the order is bottom-up and only the bottom PR gets auto-merge.
- Read the repo rules (CLAUDE.md, AGENTS.md). Where they conflict with the merge authority you gave me, the repo rules win and I'll record that as a ruling.

**2. Ledger**
- Record your merge authority for all three PRs, the `--sha` heads I checked, and who owns each PR.
- Record #91 as a human gate: Dana, review. Mirror this to the `coordinator-ledger` issue.

**3. #88 and #90 (CI running)**
- I won't sleep-poll. If a PR is otherwise READY (threads resolved, AI reviews on the current head, required approvals present), I'll enable `gh pr merge --auto --squash`, or use the merge queue if the repo has one. The merge gate allows pending checks with `--auto`. I'd skip auto-merge if the repo's branch protection doesn't cover the required checks.
- I won't enable auto-merge on a PR with open threads or a missing review. It would bypass the READY checks that `ready.sh` enforces.
- If e2e fails overnight, the sweeper reads the failing log before any rerun. It checks whether the diff touches that path and what the base history shows. A flake gets one rerun and a separate test-fix task. A real failure goes to the PR's owner.
- I won't push anything, so no head changes under the CI runs.

**4. #91 (Dana)**
- I won't self-approve or bypass the review.
- If CI is green, I request code-owner review. If not already done, I'd post one concise PR comment with the change, the risk and the evidence.
- Chat to people is human-only. I'll draft a short nudge for Dana, naming the PR, and wait for your OK before anything is sent. I won't email or DM her myself.
- I'll record the nudge on the task. I'd also ask whether another CODEOWNER could cover it.
- The missing approval stays a human gate. I report it and don't make a task for it.

**5. Keep things moving while you're offline**
- Set status to `waiting`, not `active`, with a precise next action (re-check #88/#90 e2e, merge what's READY) and a recheck of about 45 minutes. The session is then not nudged to keep working.
- Make sure a single scheduled sweeper exists and is recorded in the ledger. The example cron only runs 08:00–18:59 on weekdays, so tonight's e2e results would sit until morning. If you want overnight merges, the schedule has to cover those hours. Otherwise I'll tell you the merges wait until morning.
- After any merge, I confirm the commit is on trunk and base CI is green before I touch the next PR. If trunk auto-deploys, I schedule a deploy check.

**6. What I'd leave you with**
- A short status table with per-PR head, checks, threads, approvals and the next action. It would include real links from tool output and mark anything I didn't recheck as stale.
- Open items for you: Dana's review on #91 (human gate, with the drafted nudge awaiting your approval) and the sweeper schedule question above.
- Nothing needs credentials from you tonight.