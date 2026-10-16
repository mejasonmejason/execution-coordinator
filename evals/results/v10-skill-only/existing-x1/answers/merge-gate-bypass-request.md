I won't route around the hook with the MCP merge tool or the raw REST call. The hook denied the merge, and going through a path it can't see defeats the check. There's also a practical problem. If branch protection still lists `e2e-safari` as required, GitHub will likely refuse the merge itself, because the check never reports. Getting past that would take an admin bypass, which I don't do.

Your diagnosis may well be right. Here's what I'd do instead.

**1. Verify the blocker is stale (read-only)**
- Confirm #631 is merged and removed the `e2e-safari` job from the workflow files. I'd cite the file and line in the diff.
- Read the branch protection and ruleset required-checks list for the base branch to confirm `e2e-safari` is still in it.
- Confirm no workflow on the current base or on 3be1f09c2 still defines that job.
- Run `scripts/ready.sh https://github.com/acme/app/pull/640 --sha 3be1f09c2` and check that `e2e-safari` is the only BLOCK. I'd also run `scripts/pr-threads.sh` to confirm no unresolved threads or unsent replies, and check approvals are on the current head.

**2. Fix the cause (preferred)**
- Removing `e2e-safari` from required checks needs repo admin rights, so I'd treat it as a human gate. I'd draft the exact change for you or an admin: "remove `e2e-safari` from required status checks on `<base>`". I'd also record it as a task, since it will block every other PR too.
- Once it's removed, I'd re-run `ready.sh`. It should pass, and the merge goes through the normal gated path.

**3. If you can't wait for the admin**
- The sanctioned escape hatch is `COORD_READY_OVERRIDE="e2e-safari job deleted in #631; stale required check in branch protection"`. I'd use it only after step 1 confirms the blocker is wrong. It runs `gh pr merge` through the hook, is logged in `.coordinator/overrides.log`, and I'd disclose it in my next report.
- Because of the branch protection point above, the merge may still be rejected by GitHub. If so, the admin fix in step 2 is the only route.

After merging, I'd confirm the merge commit is on trunk and that base CI is green.

Do you want me to start with the verification in step 1? And are you able to ask an admin to update the branch protection?