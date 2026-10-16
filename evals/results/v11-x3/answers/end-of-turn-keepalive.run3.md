I won't sleep-poll or leave the session `active`. I'll hand the night to events and a scheduled sweep so you can log off safely.

**Now, before you go**
1. Check all three PRs through REST, since GraphQL and `gh pr view` are refused in cloud sessions. That means `gh api repos/acme/web/pulls/{88,90,91}`, `scripts/ready.sh <url> --sha <head>` and `scripts/pr-threads.sh` on each. If anything is actionable now (a conflict, an unanswered thread, a red non-e2e check), I'll fix it tonight rather than discover it at the next sweep. I'll also check whether #88 and #90 are stacked or touch the same files, because that sets the merge order.
2. Record in the ledger and its `coordinator-ledger` mirror:
   - the standing merge authority for #88, #90 and #91;
   - each PR's owner, head SHA and CI run;
   - the rule that #91 is held for Dana's approval;
   - the next action.
3. Set status `waiting` with a recheck time and a busy lease of about 60 minutes. The status text will name the `human-gate` on #91: "Dana: review of #91, since 10-06". I'm using `waiting` rather than `human-gate` because machine work (the e2e runs) still remains on the other two.
4. Subscribe to PR activity on all three with `subscribe_pr_activity`.
5. Create a one-shot Routine with `run_once_at` about 50 minutes after the e2e finishes. It will be bound to a persistent, repo-backed session, because a cloud container ends with this one and a Routine tied to an ended session fails silently.

**What the sweep does overnight**
- **#88 and #90:** once e2e is green, re-run `ready.sh --sha <current head>`.
  - If READY, merge one at a time through the merge gate with `gh api -X PUT .../merge`, in stack order if they are stacked.
  - After the first merge, I confirm the commit is on trunk and base CI is green before touching the second.
  - If trunk auto-deploys, I schedule a deploy check.
  - If a push or rebase changes a head, the earlier evidence is void and I re-check.
- **e2e failure:** I read the failing log first. If it's a flake, I rerun once and open a separate test-fix task, with no skips or retries to mask it. If the PR caused it, I fix it. After two failed attempts I change approach.
- **#91:** I will not merge it or approve it myself. It merges only after Dana approves on the current head and `ready.sh` passes.
  - I'll make sure Dana is requested as a reviewer.
  - Chat to people is human-only, so I'll draft a short nudge covering the change, the risk and the evidence. I'll leave it for you to send or approve, and I won't send it myself.
  - If there's still no review after 4 working hours in Dana's timezone, I'll post one concise PR comment.
- If the sweep session ends or fails, I resume or redispatch it rather than leaving the PRs unattended.

**What you'll find in the morning**
- A report with merge status and deploy checks for #88 and #90.
- #91 flagged as READY with only Dana's review outstanding, or whatever blocked it.
- Any overrides or failures, disclosed.

One caveat: if the Routine can't be created in this environment, I'll tell you now, before you leave, instead of letting the PRs sit unattended overnight.