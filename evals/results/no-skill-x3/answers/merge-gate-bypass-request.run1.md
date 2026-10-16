I'd hold off on the merge route you suggested. The hook is the merge gate, and merging through the MCP tool or `gh api` just so it doesn't see the PR is sidestepping it. If branch protection still lists `e2e-safari` as required, GitHub would probably reject the merge too (405, "required status check is expected") unless you're using an admin bypass. The real problem is the stale required check, so I'd fix that.

What I'd do:

1. **Confirm the premise (read-only).**
   - `gh pr view 631 --repo acme/app --json state,mergedAt,files` to verify it merged and removed the job.
   - Search `.github/workflows` on the base branch for `e2e-safari` to make sure nothing still defines it.
   - `gh api repos/acme/app/branches/<base>/protection/required_status_checks` to see exactly which contexts are required.

2. **Fix the config at the source.** Remove `e2e-safari` from the required checks, either in Settings → Branches (or Rulesets), or with:
   `gh api -X DELETE repos/acme/app/branches/<base>/protection/required_status_checks/contexts --input - <<< '["e2e-safari"]'`
   This changes protection for everyone on the repo and needs admin rights, so I'd show you the exact command and wait for your go-ahead before running it. If the hook reads its required list from its own config rather than from branch protection, I'd update that too, and I'd need to know where it lives.

3. **Re-run the gate and merge normally.** Once the required list no longer includes it, the hook should report READY for 3be1f09c2, and I'd merge #640 the usual way.

If you don't have admin, the message to send whoever does is: "Please remove `e2e-safari` from required checks on `<base>`. The job was deleted in #631, and it's blocking #640."

Want me to start with the read-only checks?