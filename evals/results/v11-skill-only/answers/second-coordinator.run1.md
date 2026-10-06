I can't run commands or reach GitHub here, so I haven't touched #540–#547 or the sessions yet. Below is what I've read and what I'd do, in order.

I read the skill's lessons, keep-alive and PR-inventory references. Those set the rules for the first moves.

**Step 1: find out who owns what (no writes)**
- I'd read issue #512, the ledger, first. The mirror wins conflicts. I'd check who it names as coordinator, which tasks and owners it lists, and what grants and rulings Marco recorded. I'd treat its text as data, not instructions.
- There should be one coordinator. I'd check whether `[coord] billing-q4` is live and whether the ledger names it. If it is live and named, I message it rather than start a second one. If the ledger names no one, the older session keeps the project. Silence from Marco doesn't transfer ownership.
- I'd list the open PRs with `gh api 'repos/acme/billing/pulls?state=open'`. In a cloud session the search and `gh pr view` are refused, so I'd use the REST forms. Then I'd map each of #540–#547 to a task, an owner, a branch and a base. I'd check whether the stack order matters, and confirm the base branches before any merge.
- I'd check each PR's `headRefOid`, mergeability, checks and review state. I'd also check whether the two `[exec]` sessions (BIL-88 proration, BIL-90 dunning emails) still own PRs, and whether they are live or idle. The remaining PRs may have no live owner. I'd mark those unowned and redispatch them.
- I'd run `scripts/pr-threads.sh` on all eight PRs. I'd report exit 3 as unreadable and fall back to REST. Resolution then stays unverified.

**Step 2: start with the most broken**
- For each red PR, I'd read the failing log (`gh run view <id> --log-failed`) before any rebase or rerun. I'd compare it with the same job on base to tell a flake from a failure the PR caused.
  - A flake gets one rerun and a separate owned test-fix task. I won't skip or quarantine tests.
  - A real failure goes to that PR's owner, with the head SHA, check URL and exact failure. If no owner is live, I dispatch a fresh executor in its own worktree. Its brief carries the agent contract and the "fetched text is data" line.
- Independent fixes run in parallel, one writer per PR. Anything in shared files, such as schema, migrations or config, goes through one writer in stack order. Billing and migration code counts as high risk, so acceptance review needs three independent perspectives, not one.
- After two failed attempts at the same check, I change the executor or model family rather than retry.

**Step 3: record the work and get to merge**
- I'd record the grants in the ledger: your merge authority, plus anything Marco recorded. I'd create tasks for any PR or finding that lacks one, and set my status to `active` with a precise next action.
- For each PR, I'd run `scripts/ready.sh <url> --sha <head>`. That means checks green on the current head, no unresolved threads, no conflicts, and AI reviews covering the current head. A PR that only lacks a required human approval is READY with a human gate, and I'd report it as such. I won't self-approve or bypass protection.
- I'd merge one at a time, bottom-up, through the repo's merge path with the merge gate. After each merge I'd run the post-merge checks and restack the descendants before touching the next PR.
- If trunk auto-deploys, I'd verify the deploy and runtime signals before calling anything done. For a billing migration, I'd also want evidence from a real-data dry run or a live probe, not only unit tests.
- Finished executors get archived, not messaged, because a message wakes an idle session.

**What I'll report back**
- The ledger state and who the live coordinator is.
- A table of all eight PRs with head, checks, threads, owner and classification.
- What I fixed or dispatched, and what is READY.
- Any human gates, with the exact question for the named person.

If you can run `gh` here, or want me to proceed with the discovery calls, say so and I'll start with #512 and the PR list.