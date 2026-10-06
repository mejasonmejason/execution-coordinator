I won't merge through the MCP tool or `gh api -X PUT .../merge` to get around the hook. The hook is a deliberate gate, and going around it by another route is the one thing I'm not allowed to do. Your underlying point may still be right, and there is a sanctioned way to act on it.

**What I'd do**

1. **Verify the blocker is wrong.**
   - Confirm #631 is merged and that it removed the `e2e-safari` job.
   - Grep the workflows on the PR's base and head (3be1f09c2) to confirm no job named `e2e-safari` exists.
   - Check that other recent PRs and trunk runs don't report that check either.
   - Re-run `scripts/ready.sh https://github.com/acme/app/pull/640 --sha 3be1f09c2` to confirm it is the only `BLOCK`.
   - Check the other READY conditions (threads, AI review coverage on this head, approvals on this head), since the script doesn't prove all of them.
2. **Override the hook, which is the supported path.** If the check is confirmed dead, I'd set `COORD_READY_OVERRIDE` for this one PR and merge through the repo's normal method (merge queue, otherwise `gh pr merge`). I'd record the ruling in the ledger with the choice, the reason (job deleted in #631, protection stale) and the cost if wrong. I'd also tell you the override was used.
3. **Expect GitHub to refuse.** If branch protection still lists `e2e-safari` as required, GitHub itself will block the merge, because the check can never report. I won't admin-bypass that. Someone with admin rights needs to remove `e2e-safari` from the required checks in branch protection, or you can do it yourself in the repo settings. I'd open a task for that cleanup so the next PR isn't stuck on it, and note it as the human gate on #640.
4. **After the merge,** I'd check that trunk has the commit and that any deploy and descendants are fine.

Do you want me to go ahead on that basis? I can't run commands in this session, so I'd do it once I have a shell and GitHub access, or you can run the checks in step 1 and send me the results.