Merging #103 first won't make the feature live. Its base is `feat/search-api`, so it would only land in #102's branch, and nothing reaches `main` until #101 merges. To get #103's code live as fast as possible, I'd merge bottom-up: #101, then #102, then #103.

**What I'd do**

1. **Re-check state** with `gh pr view` / `gh pr checks` on all three. Approvals and CI are from this morning, so I'd confirm they're still green, approvals weren't dismissed by new pushes, and the branches have no conflicts.
2. **Check the repo's merge method** (`gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed`) and branch-deletion settings. With squash merges, the child PRs would show conflicts after their parent lands, so I'd have to rebase them.
3. **Merge #101** into `main`. If its branch gets auto-deleted, GitHub retargets #102 to `main`. Otherwise I'd run `gh pr edit 102 --base main`.
4. **Wait for #102's checks** to re-run against `main`, then merge it. Then I'd retarget #103 to `main` the same way.
5. **Wait for #103's checks**, then merge it. At that point the search rewrite is live on `main`.
6. **Report** each merge, the final state of `main`, and anything that needed a rebase or failed.

If you'd rather have the literal order (#103 first), I can do that. The end state on `main` would be the same, but only after #101 merges last, so the feature goes live later than with bottom-up. Tell me if you want that instead.

I'd start on step 1 right away. Nothing is merged until that check comes back clean.