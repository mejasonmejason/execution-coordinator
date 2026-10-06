I'd merge the stack bottom-up (#101, then #102, then #103) instead of #103 first. #103's base is `feat/search-api`, not `main`. Merging it first would only fold it into #102's branch, and nothing would reach `main` or go live. Going bottom-up gets the feature live faster than any other order. Your instruction covers all three PRs, so I'd treat it as standing merge authority for them and not ask again.

**Before any merge**
1. I'd record the stack, the merge authority and the reason for the order in the ledger.
2. "Green and approved this morning" is stale, so I'd re-check each PR on its current head. That means the head SHA, mergeability, required checks, approvals, and a thread audit with `scripts/pr-threads.sh`. In a cloud session I'd use the REST forms (`gh api repos/acme/catalog/pulls/N`).
3. I'd run `scripts/ready.sh <url> --sha <head>` on each PR. A push or rebase since this morning invalidates the earlier approvals.

**Merging**
1. **#101 (base `main`):** I'd merge it through the merge gate, using the repo's merge queue if it has one and its normal merge method otherwise. Then I'd confirm the merge commit is on `main` and that CI on `main` is green.
2. **#102:** I'd retarget it to `main` and restack it onto the new trunk. If the repo squash-merges, this step matters most. I'd verify the remote ancestry and base, wait for CI on the new base, re-run READY, then merge. I'd check that the new head is still approved and that commits are still signed if the repo requires it.
3. **#103:** I'd do the same retarget, restack, CI, READY and merge. Once it lands, the feature is on `main`.

**Stopping conditions**
- If a restack changes a head and the repo dismisses approvals on new commits, that's a human gate. I'd tell you which PR needs re-approval, name the reviewer, and keep working on the others. I wouldn't bypass branch protection or self-approve.
- If any step turns `main` red or leaves it unknown, I'd stop merging and make that the top task.
- If READY fails, I'd task each block and fix it, and I'd tell you which PR is holding up the feature.

**After merging**
- I'd check whether `main` auto-deploys. If it does, I'd schedule a deploy check and verify the rollout and a search journey on the deployed build, not just the green merge.
- I'd close the tasks with evidence, archive any idle executor sessions, and send you a report with links to the PRs, merge commits, and CI and deploy runs.

I'd tell you right away if the order changes or anything blocks.