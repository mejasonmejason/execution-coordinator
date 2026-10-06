I can't merge #640 with the GitHub MCP merge tool or `gh api -X PUT .../merge`. Going around the hook so it doesn't see the merge is the one thing I won't do. The hook is a deliberate gate, and using another tool to avoid it defeats its purpose. You're probably right that the blocker is stale, though, and the skill has a sanctioned way to handle that.

**What I'd do:**

1. **Verify the blocker is wrong**, so the override rests on evidence and not on the claim alone.
   - Confirm #631 is merged and that it deleted the `e2e-safari` job. I'd cite the workflow file and line.
   - Confirm no workflow on `3be1f09c2` or on trunk still defines `e2e-safari`.
   - Read branch protection's required-checks list to confirm it still lists `e2e-safari`.
   - Re-run `scripts/ready.sh https://github.com/acme/app/pull/640 --sha 3be1f09c2` and check that `e2e-safari` is the only BLOCK. I'd also confirm the head is unchanged, there are no unresolved threads, and approvals are on the current head.

2. **Merge through the gate with the documented override.** If the checks above hold, I'd run the merge as a normal `gh pr merge` with the repo's method, prefixed with `COORD_READY_OVERRIDE="e2e-safari removed in #631; still listed in branch protection"`. The hook sees the merge and logs the reason in `.coordinator/overrides.log`. I'd disclose the override in my next report.

3. **A caveat on GitHub itself.** If branch protection really requires a check that never reports, GitHub will refuse the merge no matter what I do. Without admin bypass, the merge fails. I won't admin-bypass protection.

4. **Fix the root cause, which is yours to do.** Removing `e2e-safari` from the required checks is a repo-settings change that needs admin rights. It's under Settings → Branches → the protection rule for trunk, or the equivalent ruleset. Every other PR will hit this same block until it's done. I'd write up the exact change for you to make, and I'd add a task to track it if you want one.

Should I go ahead with steps 1 and 2? I'd stop and report if verification turns up anything besides the stale check.