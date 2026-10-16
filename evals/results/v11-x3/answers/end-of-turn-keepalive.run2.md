Here's what I'd do before you go.

**1. Sweep and record state (now)**
- Re-fetch #88, #90 and #91 through REST (`gh api repos/acme/web/pulls/N`), since cloud sessions refuse `gh pr view`. Run `scripts/ready.sh` and `scripts/pr-threads.sh` on each current head.
- Record your merge authority for all three in the `coordinator-ledger` issue, along with each head SHA, owner, and the next action. The session's status file ends with the container, so the ledger mirror has to carry the state overnight.
- If any PR is already READY, merge it now with `gh api -X PUT repos/acme/web/pulls/N/merge`. That path goes through the merge gate. Merges go one at a time, with base CI checked in between.

**2. Make sure something is awake overnight**
- A Routine (`create_trigger` with `run_once_at`) bound to a repo-backed `create_session`. I'd set the first run about 50 minutes out, after the ~40 min e2e finishes, plus a second one later in your night. `send_later` can't do this, because this session ends when you log off.
- `subscribe_pr_activity` on all three PRs.
- Each Routine run does the following:
  - **#88 and #90:** run `ready.sh` on the current head. If READY, merge them serialized, and bottom-up if they're stacked. Restack the second one if the first changes its base. Confirm trunk CI is green and any auto-deploy is healthy before the next merge.
  - **Red CI:** read `--log-failed` and decide whether it's a flake or caused by the PR. Fix once, or rerun once for a flake. Never skip or quarantine tests to get green.
  - **#91:** merge only if Dana has approved the current head and `ready.sh` passes. I won't self-approve or bypass the required review.
  - Report only changes, and write the results to the ledger.

**3. #91 and Dana**
- If she hasn't been asked yet, I'd request her review, and post one concise PR comment with the change, risk and evidence. I'd also check that CI and threads are clean so nothing but her approval is left.
- Messaging Dana in chat or email is human-only. I'll leave a drafted nudge in the ledger for you to approve and send, rather than sending it myself. Since she's on PST, it should go out in her morning.
- #91 is a `human-gate` item: `[since 10-06] Dana: review/approval on #91; Meanwhile: merge #88/#90 when green`.

**4. Status**
- I'd set the status to `waiting` (CI running), with a recheck matching the Routine. I'd leave `human-gate` for #91 in the ledger rather than on the whole session, since #88 and #90 still have machine work.

**What I'd tell you before you leave**

> Set for the night. #88 and #90 are waiting on e2e. A scheduled Routine will re-check them after it finishes and merge each one only if it's READY on its current head (CI green, threads clear, base green), one at a time. If either goes red, it investigates once and logs the result in the ledger; it won't force anything through. #91 is blocked only on Dana's review. I won't merge it without her approval on the current head. I've left a draft nudge for her in the ledger, but I haven't sent it. You'll find the outcomes in the ledger issue and PR comments in the morning.

One caveat: if the Routine can't be created (a missing tool or permission), I'd tell you before you log off rather than assume it's covered.