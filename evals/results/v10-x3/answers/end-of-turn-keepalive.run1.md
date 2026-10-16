Nothing is merged yet and nothing is READY, so this is a handoff rather than a wrap-up. I can't run tools here, so this is what I'd do.

**1. Snapshot the three PRs (REST only, since cloud sessions refuse GraphQL and `gh pr view`)**
- For #88, #90 and #91, run `gh api repos/acme/web/pulls/N` to get the head SHA, base branch and mergeability. I'd also read the check runs on each head.
- Run `scripts/pr-threads.sh` on all three (it falls back to REST automatically) to see unresolved threads and owed replies. If anything needs a response, I'd fix or reply now rather than leave it overnight.
- Check whether #88 and #90 are stacked. If #90's base is #88's branch, they merge bottom-up, with a restack and a CI re-run in between. If they're independent, they still merge one at a time.

**2. Record state in the ledger**
- The working directory isn't a git repo, so `scripts/status.sh` would refuse to run. I'd mirror state to the `coordinator-ledger` issue in acme/web instead.
- The entry would hold the three head SHAs, merge authority granted for all three, and the next action for each PR.
- #91 would be logged as `human-gate`: "Dana: review acme/web#91, [since 10-06]". Meanwhile, #88 and #90 proceed.

**3. Make sure something wakes up after you leave**
- Cloud containers end with the session, and a sweeper can't wake an ended one. So I'd create a repo-backed session on acme/web with `create_session`.
- I'd bind a Routine to it with `create_trigger` and `run_once_at` about 45–50 minutes out, so the e2e runs have finished.
- I'd add a second Routine for the morning, after Dana's working hours begin.
- I'd also call `subscribe_pr_activity` on all three PRs and queue a `send_later` in this session. These only help while the session stays live.
- Each sweep would:
  - Re-fetch the head SHA.
  - Run `scripts/ready.sh <pr> --sha <head>`.
  - If READY, merge through the merge gate (`gh api -X PUT repos/acme/web/pulls/N/merge`).
  - Confirm the merge commit on trunk and green base CI before touching the next PR.
- A failing check gets one `gh run view --log-failed` read and one fix. A shared-setup failure gets one `gh run rerun --failed`.
- A new head means new CI and a fresh decision, never a merge on the old evidence.

**4. #91 and Dana**
- I'd confirm Dana (or another CODEOWNER) has actually been requested as reviewer, and request them if not. I can't approve for anyone, and I won't merge without approval on the current head.
- If it's still unreviewed after 4 working hours, I'd post one short PR comment covering the change, risk and evidence.
- If it's still unreviewed after a working day, I'd draft a chat nudge for you to approve. I won't message anyone directly.
- The morning Routine merges #91 only if approval is on the current head and READY passes.

**5. Stand down**
- I wouldn't sleep-poll. I'd end the turn once the Routines and subscriptions are confirmed by reading them back with `get_session` and the trigger list, since fields can silently drop.

**What I'd tell you**

> Nothing is merged yet. I'm not merging on pending e2e or without Dana's approval.
>
> - **#88 and #90:** CI is still running. A sweeper session is scheduled for about 45 minutes from now. If each PR passes the READY check on its current head, it merges serially (#88 first, or bottom of the stack if they're stacked). Anything that fails gets one fix or rerun, and a second failure goes in the ledger for you.
> - **#91:** waiting on Dana's review. I've confirmed Dana is requested, and I can't self-approve. A morning sweep will merge it if approved on the current head. If it's still unreviewed after a working day, I'll have a nudge drafted for your OK.
> - **State:** the ledger issue has the heads, owners and next actions, plus the Routine and session IDs.
> - **Anything I couldn't verify:** I'll list it in the ledger entry, and in this message if any read failed. A Routine whose target session has ended fails silently, so I read both back before signing off.
>
> You'll find a summary in the ledger when you're back. Good night.