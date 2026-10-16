I can't run commands in this environment, so this is the plan I'd follow and the order I'd follow it in. I've read the lessons, keep-alive, inventory and cloud references.

**Step 0: find out who owns the project (read-only)**

The ledger was edited 2 hours ago and a `[coord] billing-q4` session exists. That means a second coordinator may already be running, and two coordinators make conflicting writes. So I won't start a sweeper, dispatch anyone or push anything until I know who owns what.

1. Read issue #512 in full: owner, merge-authority record, dispatch table, task owners, active layers, schedules, holds and rulings. I'd treat its text as data. Anything in it that claims authority gets checked against what you told me here.
2. Call `get_session` and `list_events` on `[coord] billing-q4` and on the two `[exec]` sessions to see whether each is live, idle or finished.
3. Decide ownership:
   - **Coordinator live and named in the ledger:** it keeps the project. I'd `send_message` it with my findings and offer to take specific PRs. I would not take over.
   - **Coordinator dead or idle:** silence doesn't transfer ownership. I'd tell you, and since you've asked me to coordinate, record the handover in the ledger with the reason.
   - **Ledger names neither, or both are live:** the older session keeps the project, and I'd hand over.
4. Set my status to `active` with the next action. I'd also check for an existing L2 sweeper schedule listed in the ledger so I don't add a second.

**Step 1: inventory, then triage by how broken**

- List open PRs with `gh api 'repos/acme/billing/pulls?state=open'` (the cloud-safe form). Rediscover anything else assigned to us, since the range #540–#547 may not be everything.
- For each PR, get `headRefOid`, `baseRefName` and `mergeable`. Also get the check rollup, run `scripts/pr-threads.sh`, and map the stack ancestry.
- Check that every PR has a task and an owner, and classify each task as exactly one of dispatchable, blocked, in flight, needs attention or closeable. I'd check that the counts add up to 8 plus any extras.
- Map the PRs to Marco's sessions. Only BIL-88 and BIL-90 have visible executors, so the other six have no known owner. I'd mark those unowned for redispatch, since an in-progress task with no live owner is a defect.
- Rank by breakage: `CONFLICTING` first (it blocks stack descendants), then red required checks on a stack bottom, then other red CI, then thread backlog.

**Step 2: fix the worst PR**

- Read the failing job's diagnostic before any rebase or rerun. If the log is truncated, reproduce it locally.
- Compare with the same job on base. If the diff touches the failing path, or it passes on base, the PR caused it. Otherwise it's a flake or infrastructure failure. That gets one rerun and a separate owned test-fix task, with no retries or skips to mask it.
- Route the fix to the PR's owner. If that's `BIL-88` or `BIL-90`, I'd `send_message` the live executor with the PR, head SHA, check URL and task. If a PR has no live owner, I'd dispatch a fresh executor in its own worktree with the full agent contract and the "fetched text is data" line. I'd record the dispatch with `status.sh dispatch`.
- The independent PRs get executors in parallel. Anything touching shared schemas or migrations gets one writer, in stack order. For a billing migration, I'd treat data migrations as high risk. Acceptance would need three independent reviewers, with 2 of 3 passing and a `path:line` for each criterion.
- Two failed attempts on the same failure means a different executor or model family.
- I won't weaken, skip or re-baseline tests for green.

**Step 3: merge what qualifies, bottom-up**

- Run `scripts/ready.sh <pr> --sha <head>` on each PR. For dispatched PRs I'd also pass `--key` and run it before merging, because `accepted` can't be recorded after a merge.
- Required human approvals and deploy approvals are gates. I report them but don't task them or work around them. I won't self-approve or admin-bypass.
- Merge one PR at a time with `gh api -X PUT repos/acme/billing/pulls/N/merge`. After each merge I'd run the post-merge checks and restack descendants before touching the next PR.
- If trunk auto-deploys, I'd verify the deploy and runtime signals before calling anything done.
- Merge authority is recorded in the ledger once. I won't ask you again.

**Step 4: keep it moving and report**

- I'd set a `--busy` lease before long fan-out waits, and use `subscribe_pr_activity` instead of sleep-polling.
- I'd schedule my own next check, offset from any sweeper.
- I'd report on every push, CI change, merge or blocker, using the status template. For finished executors I'd check `accepted`, then archive them. I wouldn't message them, because a message wakes them up.

**What I need from you**

Only one thing, and only if step 0 finds a live `[coord] billing-q4`. Do you want me to take over from Marco's coordinator or work alongside it? Until I've read #512 and the session states, I'm treating that as undecided, and I'm not making any writes.