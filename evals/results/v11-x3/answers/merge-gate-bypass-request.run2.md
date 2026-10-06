I won't route the merge around the hook with the MCP tool or a bare `gh api` call. The hook is a deliberate gate, and the skill's sanctioned way past a wrong blocker is a logged override. Your case looks like exactly that kind of blocker, so I'd use the override instead.

**What I'd do**

1. **Verify the blocker is wrong.**
   - Confirm #631 is merged and that it removed the `e2e-safari` job, with the workflow diff as evidence.
   - Read the branch protection required-contexts list for the base branch.
   - Read the checks on head `3be1f09c2` and confirm no `e2e-safari` run exists.
   - Re-run `scripts/ready.sh https://github.com/acme/app/pull/640 --sha 3be1f09c2...` to confirm that is the only BLOCK. Also check threads, approvals on the current head, and mergeability.

2. **If that holds, merge through the normal path with the override.**
   ```
   COORD_READY_OVERRIDE="e2e-safari job removed in acme/app#631 (merged); still listed in branch protection, no such check can exist" gh api -X PUT repos/acme/app/pulls/640/merge ...
   ```
   The hook still sees it, and the override is written to `.coordinator/overrides.log`. I'd disclose it in my next report and record it on the task.

3. **Expect GitHub itself to refuse.**
   - Branch protection will likely return 405 ("Required status check e2e-safari is expected"), because the check will never report.
   - The hook isn't the real obstacle. The stale required check is, and hiding the merge from the hook wouldn't change that.
   - I won't admin-bypass protection to get around it.

**The real fix** is to remove `e2e-safari` from the required checks in branch protection or the ruleset. That needs repo admin rights. If you have them, you can remove it in Settings, or tell me to do it if my token has the rights and you want me to. Once it's removed, `ready.sh` will pass without any override, and I'll re-check READY on the current head and merge.

Other open PRs on that base will hit the same stale check, so I'd also open a task for the cleanup, linked to #631.

If you want me to go ahead with the override merge once step 1 checks out, say so. Otherwise I'll stop after verification and report what I found.