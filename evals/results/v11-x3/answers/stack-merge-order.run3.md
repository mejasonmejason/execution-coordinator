Merging #103 first won't make the feature live. Its base is `feat/search-api`, so the merge would land the commit on #102's branch and never reach `main`. Merging into a branch that is about to merge is also how commits get stranded. To get #103 live as fast as possible, I'd land the stack bottom-up in one run, #101, then #102, then #103. The feature goes live the moment #103 reaches `main`, which is the outcome you asked for. I'll proceed that way unless you object.

**What I'd do**

1. **Set status and record the plan.** I'd set my status to `active`, and note the stack, the merge authority you've given and the bottom-up ruling in the ledger. I'd record the reason and the cost if I'm wrong, which is a few extra minutes of CI per layer.
2. **Re-verify all three PRs.** "Green and approved this morning" is stale evidence, so I'd re-check each PR on its current head. Because this is a cloud session, I'd use `gh api repos/acme/catalog/pulls/N` instead of `gh pr view`.
   - I'd confirm the heads, bases and mergeability of each PR.
   - I'd run `scripts/ready.sh <url> --sha <head>` on each and `scripts/pr-threads.sh` to check for unresolved threads.
   - A push since the approval would void it. In that case I'd report it as needing re-approval and not merge.
3. **Merge #101.** I'd run `gh api -X PUT repos/acme/catalog/pulls/101/merge` with the repo's merge method, so the merge gate sees it. Then I'd confirm the commit is on `main` and that CI on `main` is green. If it's red, I'd stop and make that the top task.
4. **Restack #102.** Its base becomes `main`. I'd retarget it, restack it, verify the remote ancestry and mergeability, and wait for CI on the new head. Then I'd run `ready.sh` again. If approval was dismissed by the push, I'd report that as a human gate.
5. **Merge #102**, with the same post-merge checks.
6. **Retarget, restack and re-verify #103**, then merge it.
7. **Verify the deploy.** If `main` auto-deploys, I'd check the rollout and the search journeys, since a merge alone doesn't prove the feature works.
8. **Close the loop.** I'd close the tasks with evidence, retire any executors, and report each merge as it happens.

**What I'd need from you**

- If a rebase dismisses an approval, the re-approval has to come from a reviewer. I can't self-approve.
- I'll tell you right away if I hit that, or if anything goes red.