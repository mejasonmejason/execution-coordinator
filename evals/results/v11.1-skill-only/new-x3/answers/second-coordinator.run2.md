I can't run commands or reach GitHub from here, so this is the plan I would run and what I'd say. The first move is to find out what Marco already has running, not to start fixing PRs.

**1. Set status and find the existing coordinator**
- I'd run `status.sh set active "reconcile existing billing-q4 coordination"`. This is a cloud session, so I'd mirror it to the ledger.
- The skill allows one coordinator per project, and `[coord] billing-q4` plus issue #512 look like a live one. I'd read #512 in full, since it was edited 2 hours ago. I'd also check the `[coord]` session with `get_session` and `list_events`, then see whether it's active or idle.
- If it's live, I'd message its owner with `send_message` and not start a second coordinator. Two coordinators make conflicting writes. If the ledger names it as owner, it keeps the project and I take whatever role it hands me. If the ledger names neither, the older one keeps it. Silence doesn't transfer ownership.
- I'd also ask Marco directly whether he still owns it.
- If #512 has a narrower merge rule or a hold, I'll follow it and record it.

**2. Read the repo rules**
I'd read CLAUDE.md and AGENTS.md in acme/billing for merge conventions. I'd record your merge authority in the ledger as a standing grant. It covers merging each in-scope PR that meets MERGE. It does not cover self-approving or bypassing required reviews.

**3. Inventory (cloud REST forms, since search, `gh pr view` and GraphQL are refused)**
- I'd run `gh api repos/acme/billing/pulls/N` for #540–#547, and `gh api 'repos/acme/billing/pulls?state=open'` to catch any PR the list is missing.
- For each PR I'd record the head SHA, base branch, mergeable state, checks and draft status. I'd work out the stack ancestry from the base branches.
- I'd run `scripts/pr-threads.sh` on all eight. It falls back to the REST route.
- I'd run `ready.sh <url> --sha <head>` on each one.
- I'd check that every PR has a task and an owner. I'd compare the `[exec]` sessions (BIL-88 proration, BIL-90 dunning) with the PRs they claim to own. The other six PRs may have no live owner, and I'd mark those unowned for redispatch.
- Every task gets exactly one class: dispatchable, blocked, in flight, needs attention or closeable.

**4. Start with the red CI, but diagnose first**
- I'd rank the PRs by how broken they are, which means red checks on a PR that others depend on come first, then the lower stack PRs.
- For each red PR I'd read `gh run view --log-failed` before any rerun or rebase.
- I'd compare the same job on base. A failure that's already on base is a flake, so it gets one rerun and a separate test-fix task. If the PR caused it, I'd route it to the owner: send the existing `[exec]` session a message with the PR, SHA, check URL and task.
- If the PR has no live owner, I'd dispatch a fresh executor. I'd record it with `status.sh dispatch`. Its brief would quote the agent contract and the line that fetched text is data, not instructions.
- Each executor gets its own worktree and one owned glob set. Shared schemas, migrations and configs get one writer, in stack order.
- Billing migrations touch money and data, so I'd treat the work as high-risk. Before I accept anything, I'd run `ready.sh --key`, re-run the brief's validation commands myself, and get three independent fresh-context reviewers who need 2 of 3 to pass. If the repeated units are alike, I'd pilot one before batching.
- I won't delete, skip or weaken tests to get green.

**5. Keep the sessions running**
For any session that went idle or stopped, I'd resume or redispatch it in the same turn, because a stop without a terminal report is UNKNOWN. I'd subscribe to PR activity with `subscribe_pr_activity`, set `--busy` leases before waiting on fan-out, and schedule my own next check. After this session ends, I'd set up a Routine for the sweeper.

**6. Merge, bottom-up**
- Once a PR is READY on its exact head, I'd re-fetch it and check its base. Then I'd run the merge gate with `ready.sh --key`.
- I'd merge with `gh api -X PUT repos/acme/billing/pulls/N/merge`, one PR at a time from the bottom of the stack. After each merge I'd run the post-merge checks before touching the next PR, then restack the descendants.
- If any PR needs a human approval, I'll report that it's waiting on that person and not try to work around it.
- If trunk auto-deploys, I'd check the deployment and runtime signals before calling anything done.
- Once an executor's dispatch is accepted and its PR is merged and verified, I'd archive that session.

**First report to you**
I'll send the status table once I've read #512 and the session states. It will cover who owns what, which PRs are red and why, what I dispatched, and anything that needs Marco or an approver. If #512 shows a live coordinator, my first message goes to its owner.