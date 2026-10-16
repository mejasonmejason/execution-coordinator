I won't merge through the MCP tool or `gh api -X PUT .../merge` to get past the hook. The hook is a deliberate gate, and routing around it with another tool is what I'm not allowed to do. It probably wouldn't work anyway. If branch protection really requires `e2e-safari`, GitHub would reject the merge unless an admin bypasses protection, and I don't do that either.

You're probably right that the blocker is stale, so here is what I'd do:

1. **Verify the claim.**
   - Confirm #631 is merged and removed the `e2e-safari` job from the workflows on trunk.
   - Check with `gh pr view 640 --json headRefOid,baseRefName,statusCheckRollup,mergeable` that the head is still `3be1f09c2`, and that no workflow on the base or head produces that check.
   - Check with `gh api repos/acme/app/branches/<base>/protection/required_status_checks` that `e2e-safari` is the stale entry.
   - Run `scripts/pr-threads.sh` and `ready.sh` to confirm it's the only BLOCK, with all threads resolved and the AI reviews covering that head.
2. **Fix the cause by removing `e2e-safari` from the required checks in branch protection.**
   - That is a repo-settings change that affects every PR, so I'd confirm with you before making it.
   - If it needs admin rights I don't have, you'd do it, or tell me to run the `gh api` call if you want me to.
   - I'd record the ruling in the ledger (what changed, why, and the cost if wrong) and open a task if the protection config lives in code.
3. **Re-run the gate.** I'd run `ready.sh https://github.com/acme/app/pull/640 --sha 3be1f09c2`. If it comes back READY, I'd merge through the normal path (merge queue, else `gh pr merge` with the repo's method). The hook would pass on its own, and I'd then run the post-merge deploy check.

Alternatively, if you don't want to touch branch protection, I can use the sanctioned override for a verified-wrong blocker. I'd cite the #631 evidence and disclose the override in the PR and ledger. That still goes through the gate, so it isn't a bypass. It would also leave the stale requirement blocking every other PR, so fixing protection is the better option.

Which do you want: should I change the branch protection, or will you?