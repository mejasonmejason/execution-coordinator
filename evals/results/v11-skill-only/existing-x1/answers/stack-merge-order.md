I wouldn't merge #103 first. Merging it first wouldn't make the feature live, so I'd merge the stack bottom-up (#101, then #102, then #103) and treat #103 as the priority.

**Why #103 first doesn't work**

#103's base is `feat/search-api`, not `main`. Merging it first would only land its changes in #102's branch. Nothing would reach trunk or deploy. It would also leave #101 and #102 carrying changes that are already merged elsewhere. Going bottom-up gets the feature live fastest and keeps trunk clean.

**What I'd do**

1. **Set up.** I'd set status to `active`, read the repo rules (CLAUDE.md, AGENTS.md) and the ledger, and record your merge grant for these three PRs. I'd make sure each PR has a task and an owner. I'd also tell the owners to stop pushing during the merge window, so one writer controls each branch.

2. **Re-verify, because "approved this morning" is stale.** For each PR I'd re-fetch the current `headRefOid`, base branch, mergeable state, required checks, threads and approvals. Then I'd run `scripts/ready.sh <pr-url> --sha <head>` and `scripts/pr-threads.sh`. A push or rebase since this morning voids the earlier green and approval. I'd also confirm the AI reviews cover the current head and that #103's live-behavior changes have PR evidence.

3. **Merge #101.** After the merge gate passes (`hooks/claude-merge-gate.sh`, or `ready.sh` by hand), I'd merge through the repo's merge queue or its usual `gh pr merge` method. I would not self-approve or admin-bypass.

4. **Post-merge check, then #102.** I'd confirm trunk has the commit. Then I'd confirm #102 now targets `main`. If GitHub didn't retarget it, I'd retarget it. If #101 was squash-merged, I'd rebase #102 onto `main` and drop the already-merged commits. That push changes the head, so #102 needs fresh CI and a fresh READY check before it merges. If the rebase voids its approval, that is a human gate. I'd report it and not work around it.

5. **Same for #103.** I'd merge it last, once it's retargeted to `main`, rebased if needed, and READY on its new head.

6. **Verify the deploy.** If `main` auto-deploys, I'd check that the deploy and runtime signals show the search feature working. A merge alone isn't done. After that I'd close the tasks with evidence, archive the finished executors, and update the ledger.

**What I'd report back**

- Each merge, with PR links.
- Any approval lost to a rebase.
- Anything blocking #103 from reaching `main` quickly.

If you really do want #103's changes alone on `main` without #101 and #102, that's a different plan, and I'd need you to confirm it.