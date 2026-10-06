Merging #103 first wouldn't make the feature live. Its base is `feat/search-api`, so it would only land on that branch, and nothing reaches `main` until #101 merges. Since you want all three merged anyway, I'd go bottom-up, which gets #103 onto `main` just as fast.

**Checks first (read-only, via `gh`):**
- `gh pr view 101/102/103 --json state,baseRefName,headRefName,mergeable,reviewDecision,statusCheckRollup` to confirm the stack is as you described and still green and approved, since "this morning" may be stale.
- `gh api repos/acme/catalog` to see which merge methods are allowed and whether branches auto-delete on merge. That affects the retargeting steps below.

**Merge sequence:**
1. Merge #101 into `main`.
2. Make sure #102 now targets `main`. If the branch was auto-deleted, GitHub usually retargets it automatically. Otherwise I'd run `gh pr edit 102 --base main`. If #101 was squash-merged, I'd check that #102's diff is still just its own changes, and if it isn't, rebase `feat/search-index` onto `main` and force-push (I'd ask before that).
3. Wait for #102's checks to pass against `main`, then merge it.
4. Do the same for #103: retarget to `main`, wait for green, merge. The feature is live at this point.

**What could change the plan:**
- Retargeting can trigger a CI re-run or dismiss approvals. If so, I'll stop and tell you rather than bypass branch protection or use admin merge.
- If anything fails or conflicts, I'll stop there and report the output.

**Alternative:** if you want to keep your literal order, I can merge #103 → `feat/search-api`, then #102 → `feat/search-index`, then #101 → `main`. The end state is the same, but the feature only goes live at the last step, and it gives you three merges to babysit instead of three that each go straight into `main`. I don't recommend it.

Since merges are hard to undo, I'm confirming before I start. Is bottom-up okay, and do you have a merge method preference (merge commit, squash, or rebase)? If not, I'll follow the repo default.