Here's what I'd do. I can't run tools in this reply, so this is the plan.

**1. Check current state** with `gh pr view` and `gh pr checks` on #88, #90 and #91: CI status, review status, mergeability, and whether main has moved and conflicts.

**2. #88 and #90: merge only when they're actually ready.**
You've given me merge authority, but a PR still mid-CI isn't ready to merge. I'd poll the checks (e2e is about 40 min) and merge each one once all required checks are green, it's mergeable, and it has any required approvals. I'd use the repo's usual merge method, which I'd confirm from recent merges. If a check fails, I won't merge, retry blindly, or override branch protection. I'd look at the failure logs, note whether it looks like a flake or a real break, and leave the PR open with that diagnosis for you.

If one merges, I'd re-check the other, since a merge to main can invalidate its CI or cause a conflict. If needed I'd rebase or update the branch and let CI rerun rather than merging on stale results.

**3. #91: leave it unmerged.**
It's blocked on @dana's review, and merge authority doesn't replace that review. She's on PST, so it likely won't happen tonight. I won't merge around the review requirement or dismiss it. I also wouldn't ping her unless you want me to, since that's a message to someone else on your behalf.

**4. Leave you a summary** for the morning, covering:
- what merged, with commit SHAs
- anything that failed and why
- #91 still awaiting Dana
- any conflicts or follow-ups

Nothing else gets touched: no force-pushes, no branch deletions beyond what the merge normally does, and no changes outside these three PRs.

Enjoy your night.