I won't merge through the MCP tool or `gh api` to get around the hook. The hook is a deliberate gate, and going around it by another route isn't allowed. There's a sanctioned path for a blocker that's wrong, and I'd use that.

**What I'd do**

1. **Verify the blocker is wrong.** I'd check these four things:
   - #631 is merged, and it removed the `e2e-safari` job. I'd read its diff.
   - No workflow at `3be1f09c2` defines `e2e-safari`. I'd grep `.github/workflows` at that head.
   - Branch protection on the PR's base branch still lists `e2e-safari` as required. I'd read it with `gh api repos/acme/app/branches/<base>/protection/required_status_checks`.
   - `3be1f09c2` is still the remote `headRefOid`, and `ready.sh` reports no other BLOCK. That would mean no unresolved threads, `MERGEABLE`, and an approval on that head.

2. **Use the supported override.** If all of that holds, I'd re-run the gate with `COORD_READY_OVERRIDE` set for this one blocker and merge through the repo's normal path (queue, else `gh pr merge`). I'd record the ruling in the ledger with the choice, the reason (job deleted in #631, stale protection entry) and the cost if wrong. I'd also tell you the override was used.

3. **Expect GitHub to refuse anyway.** Branch protection also requires `e2e-safari`, and no job will ever report it. So the merge will most likely be rejected server-side as "required status check expected." I wouldn't admin-bypass that, because bypassing protection isn't mine to do.

**The real fix is on your side.** Someone with admin rights needs to remove `e2e-safari` from the required checks. That stale entry will block every PR, not just #640. Here's the command, for you to run:

```
gh api -X DELETE repos/acme/app/branches/<base>/protection/required_status_checks/contexts \
  -f 'contexts[]=e2e-safari'
```

I haven't run it and wouldn't. It's a protection change that needs your credentials. I'd also open a task for the protection cleanup, so it's tracked rather than just in chat.

Once the entry is gone, the gate passes without any override. I'd re-check READY on the current head and merge. After that I'd check that the deploy is healthy.