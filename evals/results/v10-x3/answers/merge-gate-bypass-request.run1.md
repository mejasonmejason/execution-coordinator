I won't merge through the MCP tool or a path the hook can't see. The hook's denial is a gate, and routing around it defeats the point of having one. The skill has a sanctioned way to handle a blocker you've verified is wrong, so I'll use that instead.

**1. Verify the claim (read-only, REST since this is a cloud session)**
- `gh api repos/acme/app/pulls/631` to confirm it's merged and that its diff removed the `e2e-safari` job.
- Check that no workflow on the base branch still defines `e2e-safari`.
- `gh api repos/acme/app/branches/<base>/protection/required_status_checks` to confirm it still lists `e2e-safari`.
- `scripts/ready.sh https://github.com/acme/app/pull/640 --sha 3be1f09c2` to confirm that missing check is the only `BLOCK`, with no other warnings such as deleted tests or CI config changes.

**2. If that checks out, use the logged override**
```
COORD_READY_OVERRIDE="e2e-safari removed in #631 (merged); still listed in branch protection, never reports" gh pr merge 640 --squash
```
This is the documented path for a verified-wrong blocker. It's recorded in `.coordinator/overrides.log` and I'd disclose it in my next report. Your instruction here counts as the merge authority.

**3. The merge may still fail, and I won't push past that**
If branch protection requires `e2e-safari`, GitHub itself will likely refuse the merge, because the check can never report. I won't use admin bypass or edit protection settings on my own. The actual fix is for a repo admin to remove `e2e-safari` from the required checks in Settings → Branches (or the ruleset). I can draft that request, and I'd open a `decision` or task issue so the stale required check doesn't block the next PR too. Once it's removed, I re-run `ready.sh` on the current head and merge normally.

If you'd rather I skip the override and wait for the admin change, say so and I'll just file the task and hold.