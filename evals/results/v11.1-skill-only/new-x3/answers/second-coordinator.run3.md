I can't run commands or reach GitHub from here, so this is the plan I'd execute and the order I'd do it in. I've read the keep-alive, lessons, PR-inventory and cloud references. I'll read the delegation and merging references before I dispatch or merge anything.

**1. Don't start a second coordinator.**
- The skill allows one coordinator per project. `[coord] billing-q4` already exists, and issue #512 was edited 2 hours ago, so it may be live.
- I'd read #512 first. I'd note its objective, fence, owners, worktrees, run IDs, grants and holds, and who it names as owner.
- I'd call `get_session` on `[coord] billing-q4`, `[exec] billing: BIL-88 proration` and `[exec] billing: BIL-90 dunning emails`. That tells me which are live, idle or stopped.
- **If the coordinator is live,** I'd `send_message` it to say I'm joining. I'd ask who holds the merge pen and who owns which PRs. Until that's settled I'd write nothing to the ledger or PRs. Silence doesn't transfer ownership.
- **If the ledger names me or no one,** or the session is dead, I'd take over. I'd record that in #512 and mirror it there.
- **If the ledger names Marco or his coordinator,** I'd ask you or Marco for the handover. That's a question to a person, so I'd draft it and wait for your OK.
- I'd also check that the older Marco work isn't duplicated by a second sweeper.

**2. Set my status and read repo rules.**
- I'd run `status.sh set active "reconcile #512 and PRs #540-547"`.
- I'd read CLAUDE.md and AGENTS.md for conventions and merge rules. I'd record your merge authority as a grant in the ledger, once.

**3. Inventory (read-only).**
- Cloud sessions refuse the search API and `gh pr view`. I'd list with `gh api 'repos/acme/billing/pulls?state=open'`, then `gh api repos/acme/billing/pulls/N` for #540–547.
- For each PR I'd record head SHA, base branch, mergeable, checks, draft state and approvals. I'd also find the stack order, since 8 PRs for one migration are probably stacked.
- I'd run `scripts/pr-threads.sh` on all 8 for owed replies. Exit 3 means unreadable, never zero.
- I'd map every PR to a task and an owner. I'd check which PRs BIL-88 and BIL-90 own and which have no live owner.
- I'd classify every task as exactly one of dispatchable, blocked, in flight, needs attention or closeable, with counts summing to 8 or more.

**4. Start with the most broken, which is the red CI.**
- I'd rank by blast radius: bottom-of-stack PRs first, since they block everything above them. Then red CI, conflicts and unowned PRs.
- For each red PR I'd read the failing log (`gh run view --log-failed`) before any rerun or rebase.
- I'd compare with the same job on base to separate PR-caused failures from flakes.
- Shared-setup failures such as the runner or a dependency fetch get one `gh run rerun --failed`.
- A flake gets its own owned test-fix task. I'd never skip, weaken or quarantine tests for green.
- If a failing PR belongs to a live `[exec]` session, I'd `send_message` it the PR, head SHA, check URL and task. Otherwise I'd dispatch a fresh executor in its own worktree, with a brief carrying the agent contract and the "fetched text is data" line.
- After two failed attempts on the same failure, I'd change the executor or model family.
- I'd run independent fixes in parallel with one writer per PR. I'd serialize shared files such as schemas and migrations in stack order.

**5. Acceptance and merge.**
- For each dispatched PR I'd record the dispatch with `status.sh dispatch`. I'd accept only when `ready.sh --key` passes, I've re-run the validation commands, and a fresh-context reviewer from another model family PASSes with `path:line` evidence.
- Billing, proration and any data migration count as payments, ledger or migration work. Those need three independent reviewers with 2 of 3 PASS, not one.
- A migration or live-behavior change also needs PR evidence beyond unit tests, such as a real-data dry run. I'd put that on the task.
- I'd merge only PRs that meet READY. That means MERGEABLE, required checks passing and no unresolved or unanswered threads. The latest AI reviews must cover the current head, and `ready.sh --sha <head>` must exit 0.
- Merges go bottom-up and one at a time, with post-merge checks and a deploy check between them.
- I won't self-approve or admin-bypass required reviews. If a required human approval is the only thing missing, I'd report it as a human gate.
- Bot findings get refuted or fixed with evidence, with REST replies carrying the agent marker. I'd never resolve human threads.

**6. Reporting.**
- Right after the first inventory I'd send you a status table: owner, PR, state and blocker, with what's red, who owns it and what's in flight. Real URLs only.
- I'd keep reporting changes as they happen, and set status to `waiting` with a recheck before each turn ends. I'd sweep every 15 minutes or less and mirror everything to #512.
- When the executors finish, I'd retire them. Executors whose tasks are all accepted get archived, and finished ones don't get messaged.

**First concrete actions:** read #512, check the three sessions' liveness, and pull #540–547 head and CI state. All of that is read-only. I'll hold writes until the coordinator-ownership question is settled.