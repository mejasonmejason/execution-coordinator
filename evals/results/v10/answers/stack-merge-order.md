Merging #103 first won't make the feature live. Its base is `feat/search-api`, so a merge would land the change on #102's branch and `main` would be unchanged. The feature reaches `main` only when #101, #102 and #103 land in that order. I'll go bottom-up and keep the gap between merges short, so the feature goes live as soon as #103 lands. #103 is the last merge, not the first.

**What I'd do**

1. **Set up.** Set my status to active, and record in the ledger that you've granted merge authority for #101, #102 and #103. Read the repo's CLAUDE.md and AGENTS.md for the merge method and any narrower merge rules. Confirm that each PR has a task and one branch writer, and tell any live owners to stop pushing while I merge.

2. **Re-verify; "green this morning" isn't enough.** In this cloud session, GraphQL and `gh pr view` are refused, so I'd use `gh api repos/acme/catalog/pulls/101` (and 102, 103) to get each PR's current head SHA, base, mergeability and open state. Then I'd run `scripts/ready.sh <url> --sha <head>` on each and `scripts/pr-threads.sh` to audit review threads. Any push since the approvals could have invalidated them, and any BLOCK becomes a task with an owner.

3. **Merge #101.** Merge it into `main` through `gh api -X PUT repos/acme/catalog/pulls/101/merge`, using the repo's method, so the merge-gate hook sees it. Then confirm the merge commit is on `main` and that base CI is green.

4. **Restack #102.** If the repo squash-merges, #102's branch no longer descends from `main`, so I'd:
   - pause pushes to the child branches;
   - rebase #102 onto `main` with the repo's stack tool, using `--force-with-lease` on the owned branch only;
   - retarget #102's base to `main`.

   I'd wait for CI on the new base and re-run `ready.sh` on the new head. If the push dismissed approvals, that becomes a named human gate and I'd report it.

5. **Merge #102**, confirm it's on `main`, then repeat the restack and verify steps for #103 (base `main`). Merge #103 and confirm it's on `main`.

6. **Verify and close out.**
   - **Deploy:** if `main` auto-deploys, I'd check the deploy and runtime signals for the search feature, not just the merge, before calling it done.
   - **Cleanup:** retire the executors and update the ledger and tasks.

**What I'd tell you**

- **Order:** "I merged #101 → #102 → #103 rather than #103 first, because #103 targets #102's branch and merging it first wouldn't put anything on `main`. The feature is live once #103 lands."
- **Re-approval:** if a restack drops an approval, I'd name the PR and the approver needed. I won't self-approve or bypass branch protection.
- **Report:** at the end I'd give the merged SHAs on `main`, the CI and deploy results, and any overrides or leftover tasks, with links.