I won't merge through the MCP tool or in any way meant to keep the hook from seeing it. That would bypass a guard rather than fix it. Your diagnosis is probably right, though, and the gate has a sanctioned override for a verified-wrong blocker. Here is what I'd do.

**1. Verify the blocker is wrong (read-only)**
- Confirm #631 is merged and that it deleted the `e2e-safari` job: `gh api repos/acme/app/pulls/631` and its file list.
- Read the required contexts from branch protection or rulesets on the base branch, and confirm `e2e-safari` is listed there.
- Confirm the head `3be1f09c2` is still the current remote head, and that no `e2e-safari` check run exists on it.
- Run `scripts/ready.sh https://github.com/acme/app/pull/640 --sha 3be1f09c2` and confirm `e2e-safari` is the only `BLOCK`. Any other block stops me.
- Run `scripts/pr-threads.sh` to check for 0 ACTION, AWAITING or UNSENT rows.

**2. Merge with the logged override, where the hook can see it**
If that is clean, I'd run:

```bash
COORD_READY_OVERRIDE="e2e-safari deleted in #631 (merged); stale required check in branch protection" \
  gh api -X PUT repos/acme/app/pulls/640/merge -f sha=3be1f09c2... -f merge_method=squash
```

The `-f sha` pin makes the merge fail if the head moved. The override is written to `.coordinator/overrides.log`, and I'd mention it in my next report. I'd use the repo's usual merge method.

**3. A problem you may hit**
If branch protection really requires `e2e-safari` and nothing reports it, GitHub itself will reject the merge as blocked. I won't use an admin bypass to get around that. The actual fix is to remove `e2e-safari` from the required checks, under Settings → Branches (or Rulesets). That is a repo-admin settings change. If you want me to make it, say so and I'll show you the exact `gh api` call first. Otherwise you can do it in the UI, and every later PR will be unblocked too.

**4. After merging**
I'd confirm the merge commit is on trunk and that base CI is green. I'd also open a small task, "remove stale `e2e-safari` required check", if the protection change isn't made today.

Should I go ahead with steps 1 and 2 now?