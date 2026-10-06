Nothing has run yet, because this environment is read-only. Here is what I'd do to wrap up, in order.

**1. Check current state**
- I'd list the three PRs with REST (`gh api repos/acme/web/pulls/N`), since cloud sessions refuse `gh pr view` and the search API.
- I'd check whether #88, #90 and #91 are stacked on each other. That decides the merge order. Stacks merge bottom-up, with a restack and new-base CI between merges.
- I'd run `scripts/pr-threads.sh` on each PR. Any open comments get a reply or a fix now, so they don't block READY later.

**2. Set up the overnight handling**
- **Event watching:** I'd call `subscribe_pr_activity` on all three PRs, so check, review and merge events reach the session. I won't sleep-poll.
- **Sweeper for after you log off:** I'd create a Routine with `create_trigger` and `run_once_at` about 45–50 minutes out. It would target a repo-backed session, since an ended or archived session silently drops the wake-up. It would also have a second, later run as a backstop. Each run would:
  - run `scripts/ready.sh <pr> --sha <current head>` for #88 and #90;
  - merge each PR that passes, one at a time, through the merge gate;
  - after each merge, confirm the commit is on trunk and base CI is green before touching the next;
  - schedule a deploy check if trunk auto-deploys.
- **Status file:** I'd run `status.sh set waiting "e2e on #88/#90; Dana review on #91" --recheck 45`.
- **Merge rules:**
  - I'd never merge on green alone. If e2e fails, I read the failing log and rerun only if it's an infrastructure flake. Otherwise I fix or redispatch the PR.
  - A new push resets READY, so I'd re-check the head SHA before merging.
  - I'd never bypass required checks or reviews.

**3. #91 stays with Dana**
- Her review is a human gate, and my merge authority doesn't cover approving it myself.
- Her working day starts hours from now. I'd record `human-gate: Dana: review #91` on the task and ledger.
- After four working hours of waiting I'd post one short PR comment with the change, risk and evidence.
- If a day passes with no review, I'd draft a chat nudge for you to approve. I won't message anyone directly.
- The sweeper would merge #91 only once the approval is on the current head and READY passes.

**4. Ledger**
- I'd update the `coordinator-ledger` issue with the PR heads, owners, the scheduled wake-ups, the merge-authority grant and next actions, so the work survives if this session ends.

**What to expect:** I'd leave you one status table with each PR's head SHA, check state, thread count, approvals and the scheduled next action. By morning, #88 and #90 should be merged and verified, unless e2e fails or a conflict appears. #91 should be waiting on Dana, with any merge following her approval.