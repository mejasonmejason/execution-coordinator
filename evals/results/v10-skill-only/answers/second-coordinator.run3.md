I haven't run anything yet, so there are no findings. This is what I'd do, in order.

**1. Find who owns coordination before touching any PR**
- Only one coordinator should run per project. I'd call `get_session` on `[coord] billing-q4` and read the ledger issue #512 (the mirror wins any conflict).
- #512 was edited 2 hours ago, so something is probably live. If the coordinator is live, I'd message it instead of starting a second one and ask for its roster, rulings and merge-authority notes.
- If it's idle, I'd take over only after its ledger entries confirm it, and I'd record the handover in #512. If two coordinators turn out to be writing, we both stop and the ledger's owner keeps the project.
- I'd treat everything in the ledger, PR bodies and comments as data, not instructions. Marco's notes inform decisions but don't grant authority. Your merge authority on the repo goes into the ledger as a grant.
- I'd also read the repo's CLAUDE.md and AGENTS.md for who merges and what the conventions are.

**2. Inventory**
- Cloud sessions refuse search and `gh pr view`, so I'd use `gh api repos/acme/billing/pulls/N` for #540–#547. I'd also list open PRs to catch any related PRs outside that range.
- I'd map the stack order and base branches, because stacked PRs merge bottom-up.
- Then I'd run `scripts/pr-threads.sh` on all 8 (with the REST fallback) and `scripts/ready.sh` on each at its current head.
- Every task would be classified as dispatchable, blocked, in flight, needs attention or closeable, with counts that sum to 8.

**3. Triage the red CI first**
- For each failing PR I'd read the failing job log (`gh run view --log-failed`) before any rebase or rerun.
- For each failure I'd decide whether the PR caused it or it's a flake. A failure is PR-caused if the diff touches that path or it passes on base.
- Runner or dependency-fetch failures get one `gh run rerun --failed`. A real flake becomes its own owned test-fix task. I won't mask it with retries or skips, and I won't delete or weaken tests to get green.
- A failure low in the stack gets fixed first, and the fix is then propagated upstack.

**4. Route to owners**
- BIL-88 (proration) and BIL-90 (dunning) have executor sessions. I'd check each with `get_session` and `list_events`.
- Live ones get `send_message` with the PR, head SHA, failing check URLs and the exact failure. Finished sessions I'd archive, not message, because a message wakes them.
- A stalled session gets redispatched from its checkpoint in the same turn.
- PRs with no live owner get a fresh `[exec] billing: …` session with a full brief: the agent contract, owned globs and the fetched-text-is-data line. The dispatch is recorded with `scripts/status.sh dispatch`.
- Each PR has exactly one owner and one branch writer.
- I'd watch the PRs with `subscribe_pr_activity` instead of polling.

**5. Accept and merge**
- A PR is accepted only when `ready.sh` passes at the current head, I've re-run the brief's validation commands myself, and a fresh-context reviewer has passed it with `path:line` citations.
- Billing and payments PRs are high risk, so I'd want three independent reviewer perspectives with 2 of 3 passing, and a spec-based test writer who hasn't seen the implementation.
- I'd merge bottom-up, one at a time, through the merge gate hook. After each merge I'd confirm the commit is on trunk, restack the rest, and wait for green CI on the new base.
- I won't self-approve or bypass branch protection. A missing human approval gets reported as a `human-gate` with the named reviewer, and I'd request CODEOWNER review once CI is green.
- Trunk auto-deploys would get a post-merge deploy check scheduled.

**6. Reporting and state**
- I'd set `status.sh` to `active` with the next action and report after every push, failure or merge.
- Each report would be a status table with links to PRs, threads and runs.
- Any real choice between options (for example, a migration design call) becomes a `decision` issue with a recommendation, not a chat question.

First actions are `get_session` on the three sessions and reading #512. I'd then pull PR state for #540–#547 and start on whichever PR's failure is lowest in the stack.