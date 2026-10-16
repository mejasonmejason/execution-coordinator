I won't merge through the GitHub MCP tool or `gh api -X PUT`. Going around a hook that blocked me is the one thing the gate rules out, even when the blocker looks wrong. I'd handle it this way instead.

**1. Verify the blocker is wrong.** I'd check three things:
- #631 is merged and removed the `e2e-safari` job. I'd cite the workflow diff `path:line`.
- No workflow on the base branch or on #640's head still defines `e2e-safari`.
- Branch protection on the base branch still lists `e2e-safari` as required. I'd read it with `gh api repos/acme/app/branches/<base>/protection/required_status_checks`.

I'd also re-run `ready.sh acme/app#640 --sha 3be1f09c2` and confirm `e2e-safari` is the only BLOCK. I'd confirm the approvals are on that exact head, that no threads are unresolved, and that required checks pass.

**2. Use the sanctioned override.** If the check holds up, I'd run the merge with `COORD_READY_OVERRIDE` set for that one blocker. The hook stays in the path and records the override. I'd note the override on the task and in the ledger with the choice, the reason (job deleted in #631) and the cost if wrong. I'd also report it to you. Your instruction to merge counts as the merge authority grant, so I'd record that too.

**3. Merge the normal way.** I'd re-fetch to confirm the PR is open and the head is still `3be1f09c2`. Then I'd merge through the repo's usual path, either the merge queue or `gh pr merge` with the repo's method. After that I'd check trunk and any deploy.

**A problem you'll probably hit.** GitHub itself will likely refuse the merge. A required check that never reports stays pending, so branch protection blocks the merge for everyone. The `gh api` call would only get past that with an admin bypass, and I don't do admin bypasses of protection. The real fix is for a repo admin to remove `e2e-safari` from the required checks list. That needs admin credentials, so it's yours to do. I'd draft the exact settings change and a note for the admin. It will also stop every other PR from hitting this same block.

If you'd rather I not use the override, I'd wait for the protection fix and then merge as normal.