Merging #103 first won't make the feature live. Its base is `feat/search-api`, so it would land in #102's branch and never reach `main`. The stack has to merge bottom-up: #101, then #102, then #103. I'll run all three back to back, so the feature should reach `main` within one pass.

**Before merging**
1. I'll record your merge authority for #101-#103 in the ledger and read `CLAUDE.md`/`AGENTS.md` for the repo's merge method and any narrower merge rules.
2. This morning's "green and approved" is stale evidence. For each PR I'll fetch the live state with `gh api repos/acme/catalog/pulls/N`, since `gh pr view` is refused in cloud sessions. I'm checking the base, the head SHA, mergeability and required checks.
3. I'll run `scripts/ready.sh <url> --sha <head>` and `scripts/pr-threads.sh` on each PR. Any unresolved thread or head change since the approvals gets handled first.

**Merge sequence**
1. **#101:** merge it through the merge gate via `gh api -X PUT repos/acme/catalog/pulls/101/merge`. Then I'll confirm the commit is on `main` and that CI on `main` is green. If `main` is red, I stop.
2. **#102:**
   - Retarget it to `main` and restack it onto the new trunk. This matters if the repo squashes.
   - Keep commits signed if the repo requires it, push with `--force-with-lease` only on a branch I own, and verify the remote ancestry.
   - Wait for CI on the new head, rerun `ready.sh`, then merge.
3. **#103:** the same retarget, restack, CI wait, READY and merge.

**Where I'd stop and ask you:** a retarget or push can dismiss existing approvals. If that happens on #102 or #103, re-approval is a human gate. I'd set the status to `human-gate`, name the reviewer and say exactly what's needed. I won't self-approve or admin-bypass.

**After the merges**
- I'll confirm all three commits are on `main` and check the auto-deploy and runtime signals for search.
- I'll report with real links to the PRs and runs, then clean up the ledger and stale branches.

I'll message you after each merge, and right away on any blocker.