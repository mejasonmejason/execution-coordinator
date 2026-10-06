I'd merge the stack bottom-up (#101, #102, #103) rather than #103 first, because merging #103 first wouldn't put the feature live.

**Why not #103 first:** #103's base is `feat/search-api`, so merging it only lands the commits on #102's branch. `main` doesn't change and nothing ships until #101 and #102 are on trunk. Going bottom-up is the fastest route to the feature being live, and all three PRs still get merged.

**What I'd do:**

1. **Set up tracking.** Record in the ledger that merge authority for #101-#103 comes from your request, and set status `active`. I'd list the PRs and branch owners with `gh api repos/acme/catalog/pulls/N`, since cloud sessions refuse `gh pr view`.

2. **Re-verify, since "green this morning" is stale.** For each PR I'd run `scripts/ready.sh` against the current head SHA and `scripts/pr-threads.sh` for the thread audit. I'd also check that approvals are still on the current head, that no threads are unresolved, and that required checks pass. I'd also stop the owners' pushes to the stack branches while I merge.

3. **Merge #101 into `main`.** I'd use the repo's merge path (queue, or `gh pr merge` with its usual method), passing the merge-gate hook. Then I'd confirm the merge commit is on `main` and that base CI is green.

4. **Restack and merge #102.**
   - Retarget #102's base to `main` and rebase it onto the new trunk. I'd use the repo's stack tool, or `--force-with-lease` only on the branch we own. This matters especially if #101 was squash-merged.
   - Re-run CI on the new head and re-run `ready.sh`. A retarget or push can invalidate this morning's approval. If it does, that's a human gate and I'll tell you who needs to re-approve.
   - Merge #102, then confirm it's on `main`.

5. **Restack and merge #103.** Same steps: retarget to `main`, rebase, wait for green CI, re-check READY, merge. After this the feature is on trunk.

6. **Verify and report.** If `main` auto-deploys, I'd schedule a deploy check and verify rollout and the search journey before calling it done. Then I'd tidy up: close the tasks with evidence and archive any finished executor sessions.

**What I'd tell you:**
- Right away: "Merging bottom-up since #103 alone wouldn't reach main. Re-checking current heads first."
- After each merge or blocker: the PR link, the head SHA, and what remains.
- If a retarget dismisses an approval or CI goes red, I'd say which PR and what's needed, and keep going on whatever else I can.

I won't self-approve or bypass branch protection.