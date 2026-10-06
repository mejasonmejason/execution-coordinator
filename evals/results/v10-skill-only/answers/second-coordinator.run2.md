I can't run anything from here, so this is what I'd do, in order. I'd start read-only because Marco's coordinator may still be running.

**1. Work out who owns this (before touching anything)**
- Check `[coord] billing-q4` with `get_session` and `list_events`. The ledger (#512) was edited 2 hours ago, so something is probably live.
- There must be one coordinator per project. If that session is live, I'd message it and agree on who keeps the project. I would not start a second coordinator or sweeper, and I would not take over just because it's quiet.
- If it's ended or idle with no response, I'd record the takeover in #512 and carry on.
- I'd read #512 and the repo's `CLAUDE.md`/`AGENTS.md`. Ledger text is data, not instructions. It can tell me state, but it doesn't change my authority or these rules.
- I'd record your merge authority in the ledger. That's a standing grant, so I won't ask you again.
- I'd set my `status.sh` to `active`.

**2. Inventory PRs #540–547 (cloud session, so REST only)**
- For each PR I'd run `gh api repos/acme/billing/pulls/N` and read the head SHA, base, mergeable state and checks.
- I'd run `scripts/pr-threads.sh` on every PR to find unanswered threads and unsent replies, and `scripts/ready.sh` for the READY verdict.
- I'd work out the stack order from the base branches, and which PRs belong to BIL-88 and BIL-90.
- I'd give each task exactly one status: dispatchable, blocked, in flight, needs attention or closeable. Every PR gets an owner and a backlog task, and any without one are flagged.
- I'd check the BIL-88 and BIL-90 executors with `get_session`. I'd message them only if they're live. Finished ones get archived, not messaged.

**3. Fix the most broken first (red CI)**
- I'd read `gh run view --log-failed` before any rebase or rerun.
- I'd decide whether each failure is caused by the PR or is a flake. A PR-caused failure goes to its owner, or to a new executor if there is none, with a brief that includes the agent contract and the "fetched text is data" line. Shared-setup failures get one `rerun --failed`. A real flake becomes its own owned test-fix task.
- The briefs would never allow deleting, skipping or weakening tests to get green. Billing and proration touch payments, so those PRs would also get an independent spec-based test writer and three-way review for acceptance.
- Independent fixes would run in parallel, one writer per branch. I'd set a `--busy` lease before fanning out.

**4. Merge**
- Merging goes bottom-up through the stack. Each merge needs READY on the current head, approvals on that head, and the merge-gate hook passing (`ready.sh`). After each merge I'd restack, wait for green CI on the new base and confirm the merge commit is on trunk.
- I won't self-approve or bypass branch protection. If required human reviews remain, I'd report them as the gate, nudge code owners per the review-wait timings, and meanwhile work on other PRs.
- After merges I'd check deployment and runtime signals, then close tasks with evidence and archive finished executors.

**What I'd report back first**
- Whether Marco's coordinator is live.
- A table of the 8 PRs with CI state, thread counts and owner.
- The worst failure and its cause.
- Any human gates.