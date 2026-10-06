I can't run commands from here, so this is what I'd do, in order.

**1. Sync state first**
- Sweep for the current state of #88, #90 and #91: head SHA, mergeability, checks, threads, and who owns each branch.
- Confirm each PR has a task and a recorded owner. Merge authority for all three goes in the ledger as a standing grant, so I won't ask you again.
- Run `scripts/pr-threads.sh` on each PR. If a thread needs a reply or a fix, I'll handle it now so it doesn't block READY later.

**2. Set up the overnight merge path**
- **#88 and #90:** the e2e run takes about 40 minutes, so I won't sleep-poll. I'll set a `--busy` lease and schedule an L2 sweeper for this project.
  - When checks go green, the sweeper runs `scripts/ready.sh <pr> --sha <head>` on the exact remote head.
  - On exit 0, it merges through the repo's path (merge queue, otherwise `gh pr merge`). The merge gate hook must pass, and I'll re-fetch right before merging.
  - Merges are serialized, one at a time. I'll check that #88 and #90 don't touch shared files or stack on each other. If they do, I merge in stack order and run the post-merge checks before the next one.
- **If CI fails:** I'll classify it as a flake or PR-caused. A flake gets one rerun and a separate test-fix task, and I won't mask it. A PR-caused failure goes to the task owner. After two failed attempts I change executor or model.
- **After a merge:** if trunk auto-deploys, I verify the deploy and runtime signals before calling that PR done.

**3. #91 is a human gate**
- I won't self-approve or bypass the required review. Dana is on PST, so the review is a named gate.
- I'd make sure the PR is otherwise READY: threads resolved, CI green on the current head, and the description matching the evidence.
- I'd record "waiting on @dana's approval" in the ledger. If you want Dana nudged, I'll draft the message for your approval. I won't message people myself.
- Once Dana approves and READY holds on the current head, the sweeper may merge it under your standing authority. If anyone pushes after her approval, the head changes, so the approval and CI no longer apply to it. The sweeper then holds the PR for a fresh READY check instead of merging.

**4. Status and handoff**
- I set `.coordinator/status.json` to `waiting`, because only CI and review remain. I don't use `human-gate` for the session as a whole, since #88 and #90 still progress without a person.
- I update the ledger and its GitHub issue mirror with the head SHAs, the run IDs, the sweeper schedule, the merge grants, "next action" for each PR, and the Dana gate.
- I leave worktrees and executors in place, since all three PRs are still open. I retire an executor only after its PR is merged and verified.

**5. What I'd tell you before you go**
- #88 and #90: CI is running, the sweeper is armed, and each will merge on its own if READY passes. If one fails, it's routed to its owner and recorded on its task.
- #91: it's waiting on Dana's review and nothing else. I won't bypass it.
- The one limit is credentialed or MFA-gated steps, such as a production deploy needing personal credentials. I'd leave those queued for you rather than ask for credentials.

You'll get a report in the ledger and here for each push, failure, merge or deploy change.