I wouldn't merge #103 first. Merging it first wouldn't put the feature live, and it could lose the code.

**Why not**
- #103's base is `feat/search-api`, which is #102's branch. A merge there lands the commits on that feature branch, not on `main`. Search wouldn't be live.
- The stack rules say to merge bottom-up and never merge into a branch that is merged or about to merge, because those commits never reach trunk. If #102 later merges and its branch is deleted, #103's commits could be stranded. The merge gate would probably block it too.
- The quickest route to a live feature is to merge #101, then #102, then #103, one after another. #103 is the last merge and the one that makes the feature live. The other two are prerequisites, not "whenever" work.

**What I'd do**
1. **Set up.** Check for an existing coordinator or ledger for this stack. Record the objective (#103's code live on `main`), the stack order, and your instruction to merge as the merge authority. Set status to `active`.
2. **Re-verify, since "green and approved this morning" is stale.** For each PR, re-fetch the remote head and run `ready.sh <pr-url> --sha <head>`. That checks:
   - Green required checks, `MERGEABLE`, and no owed replies.
   - Approvals that still cover the current head. A push after this morning's approval voids them.
   - AI review coverage on the head, and unresolved threads.
   - That each PR's base is the one you described.
   
   I'd task any BLOCK. A missing required approval is a human gate that I'd report to you, not work around. I wouldn't self-approve or admin-bypass.
3. **Merge #101.** Use the repo's merge queue, or `gh pr merge` with the repo's method. The merge gate hook runs `ready.sh` again. Then confirm the merge commit is on `main` and base CI is green. If base CI is red or unknown, I stop and make that the top task.
4. **Retarget and merge #102.** Retarget #102 to `main`. Restack it if the squash changed history, and check that signed commits stay signed. Then confirm the base and mergeability, wait for CI on the new head, re-run `ready.sh` with a fresh SHA and merge. Verify again that the commit is on `main`.
5. **Retarget and merge #103.** Do the same: retarget to `main`, restack, wait for CI, re-run READY and merge. Because it's the last merge, the feature lands on `main` as soon as the other two are in.
6. **Verify deployment.** If `main` auto-deploys, I'd check the deploy and runtime signals for search. A merge doesn't prove it's working. Then I'd prune the stack, archive the executors, close the tasks with evidence, and report with real links.

**What I need from you**
- Confirm you're fine with the order #101, #102, #103. It's required for the feature to go live. Tell me if there's a hard reason to ship #103 on its own. Then I'd look at a different route, such as retargeting #103 to `main`, but only if it doesn't depend on #101 and #102.
- Confirm that merge authority applies to all three.

I can't run commands or reach GitHub from here, so none of this has been run. The first thing I'd run is the re-verify in step 2.