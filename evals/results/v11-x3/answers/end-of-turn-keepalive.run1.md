I'll set things up so the merges can happen without you. The CI runs and Dana's review need time, not you.

**What I'd do now**

1. **Read the current state.** For #88, #90 and #91 I'd use `gh api repos/acme/web/pulls/N` (cloud sessions refuse `gh pr view`) to record each head SHA, base branch and mergeability. I'd also check whether the three are stacked, because that decides the merge order.
2. **Write to the ledger.** I'd record your standing merge authority for these three PRs, their heads, who owns each, and the schedule below. I'd mirror it to the `coordinator-ledger` issue so any other session or sweeper sees the same state.
3. **Audit threads on all three** with `scripts/pr-threads.sh`. Any ACTION rows get fixed or answered tonight so they don't block the morning.
4. **Make sure I wake without you.** I'd subscribe to PR activity on all three and use `send_later` to recheck #88 and #90 after the ~40 min e2e. A cloud container dies with its session, so I'd also create a one-shot Routine (`create_trigger` with `run_once_at`). It would be bound to a repo-backed persistent session, offset from the `send_later` check, and run the sweep, merge what qualifies and sync the ledger. I'd read both back to confirm the name, time and session fields saved.
5. **Set status** to `waiting` with a precise next action ("recheck e2e on #88/#90; merge on READY"). I'd mirror it to the ledger.

**What happens overnight**

- **#88 and #90:** when e2e finishes, I'd run `scripts/ready.sh <pr> --sha <head>`.
  - A failing check gets its log read first. A flake gets one rerun and a separate test-fix task, never a skip.
  - A PR that is READY with merge authority recorded gets merged, one at a time, with `gh api -X PUT .../merge`. The merge gate sees that route.
  - If they're stacked, I'd merge bottom-up. I'd confirm the commit is on trunk and base CI is green, then retarget and re-run CI on the next PR before merging it.
- **#91:** it is READY with one human gate left, Dana's approval. I won't self-approve, bypass the required review, or task it. When her approval arrives on the current head, the sweeper re-runs `ready.sh` and merges. A push to the branch voids her approval and the prior READY, so I'd hold until it's re-approved.
- **Nudging Dana:** she's on PST, so I wouldn't ping her tonight. After 4 working hours without review I'd post one PR comment. Any chat nudge to her I'd only draft for your approval, since messaging people is human-only.
- **Escalation:** if anything fails twice or hits a human-only gate, I'd set the status to `human-gate` with the exact decision and keep working on anything independent.

**What you'd see in the morning**

- Merged PRs, with the trunk commit and base CI status.
- Anything blocked, with the failing check and what I tried.
- #91 either merged or still waiting on Dana, with its head SHA.
- A list of any overrides, which should be none.

I haven't run any of this yet, so I can't tell you any PR's state. Once I've done the first read I'll send you a one-line confirmation of the schedule before you go.