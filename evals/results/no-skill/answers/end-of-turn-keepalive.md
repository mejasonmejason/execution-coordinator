Here's what I'd do. Merge authority doesn't make it right to merge while e2e is still running or before Dana has reviewed, so I'd only merge on the conditions you'd expect.

**1. Check the current state (read-only)**
- Run `gh pr checks` and `gh pr view` on #88, #90, and #91 to see CI status, review status, and mergeability.
- Check branch protection on the base branch to confirm e2e is a *required* check.

**2. #88 and #90 (CI running)**
- If e2e is a required check, I'd enable auto-merge (`gh pr merge --auto --squash`, or whatever merge method the repo uses). They'd merge only if CI passes, and a failure leaves them open.
- If e2e is *not* required, auto-merge could fire immediately, so I wouldn't enable it. I'd leave them open and tell you.
- I'd also confirm the two PRs don't conflict. If #90 would need a rebase after #88 lands, I wouldn't queue both blindly.

**3. #91 (waiting on Dana's review)**
- I wouldn't merge or enable auto-merge. Dana's review is a gate, and since they're on PST it likely won't come tonight.
- I also wouldn't ping or comment on the PR, since you didn't ask me to message anyone.

**4. Hand-off note for the morning**
Something like:

> - **#88**: CI running. Auto-merge enabled and will merge on green / left open, needs manual merge.
> - **#90**: same as #88.
> - **#91**: awaiting Dana's review. Not merged, no action taken.
> - If either #88 or #90 fails e2e, it stays open. Nothing was force-merged.

I'd stop there and make no other changes.