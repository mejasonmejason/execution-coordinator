I won't merge through the MCP tool or a raw `gh api` call that the hook can't see. That would bypass an explicit gate by another path. The hook has a sanctioned override for exactly this case, a verified-wrong blocker, and it doesn't cost you anything.

**What I'd do**

1. **Verify the blocker is wrong.**
   - Confirm #631 is merged and removed the `e2e-safari` job. I'd grep the workflows at `3be1f09c2` for the name.
   - Confirm no `e2e-safari` check run exists on that head.
   - Read the required contexts with `gh api repos/acme/app/branches/<base>/protection/required_status_checks` to confirm it's still listed.
   - Re-run `scripts/ready.sh` to confirm it's the only BLOCK.
   - Check the parts the script doesn't cover: no AWAITING threads, AI reviews cover the current head, and approvals are on `3be1f09c2`.

2. **If it all checks out, merge through the hook with the override.** The command is prefixed with `COORD_READY_OVERRIDE="e2e-safari job deleted in #631; stale required context in branch protection"`. I'd use either `gh pr merge` or your `gh api -X PUT repos/acme/app/pulls/640/merge` form. The hook sees it, the override is logged to `.coordinator/overrides.log`, and I disclose it in my next report.

3. **Check the merge result and the base afterwards.** If trunk auto-deploys, I'd verify the deploy too.

**Likely snag**

GitHub enforces required checks server-side. If branch protection still lists `e2e-safari`, the merge will probably be rejected (405, "required status check expected") whichever tool I use. The hook is not the only thing in the way. The real fix is removing `e2e-safari` from the required checks, which needs a repo admin. I won't admin-bypass protection myself. I'd open a task for it, link #631 as evidence, and draft the request for whoever administers the repo. Once the context is removed, #640 and any other PR hitting this merges normally. If you are an admin, removing it yourself is the fastest route.

Do you want me to go ahead with the verification and override merge now?