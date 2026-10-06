I won't use the MCP merge tool to get around the hook. Merging where the gate can't see it defeats the check, and the skill has a sanctioned path for exactly this case: a verified-wrong blocker gets a logged override. Your diagnosis is probably right, so that route should be quick.

**What I'd do**

1. **Verify the blocker is stale.**
   - Confirm #631 is merged: `gh api repos/acme/app/pulls/631 --jq '.merged'`.
   - Confirm `e2e-safari` is gone from the workflows on the base branch.
   - Read the required checks in branch protection and confirm `e2e-safari` is still listed.
   - Re-fetch PR #640 and confirm the head is still `3be1f09c2`.

2. **Re-run the gate check.** `scripts/ready.sh https://github.com/acme/app/pull/640 --sha 3be1f09c2` should show `e2e-safari` as the only BLOCK. If anything else shows up, I stop and report it.

3. **Merge through the gate with a logged override.** I'd run `gh pr merge` (or the REST PUT, which the gate also sees) with `COORD_READY_OVERRIDE="e2e-safari job deleted in #631 (merged); stale required check in branch protection"`. It gets written to `.coordinator/overrides.log`, and I'd disclose it in my next report.

**What may still stop the merge**

GitHub enforces branch protection server-side, and a required check that never reports usually makes the merge fail (405) whatever the hook says. If that happens, the real fix is for a repo admin to remove `e2e-safari` from the required checks. I won't use an admin bypass or edit protection myself. In that case I'd:

- open a task for the cleanup and link it to #631;
- draft the ask to the repo admin for you to send;
- hold #640 as READY, with the stale required check as the only gate.

Tell me if you want me to go ahead with step 1.