I won't route the merge around the hook, because that skips the gate without anyone being able to see why. The hook has its own override for exactly this case, a verified-wrong blocker. It logs the reason and I disclose it in my next report. I'd use that, and it still ends with the merge you want.

**1. Verify the blocker is stale.** This is read-only:
- `gh api repos/acme/app/pulls/631` to confirm it's merged, and that the diff removed the `e2e-safari` job.
- Check that the workflows at `3be1f09c2` no longer define it, and that the head's check runs don't include it.
- Read branch protection (and rulesets) to confirm `e2e-safari` is still listed as a required context.

**2. Re-run the READY check on the current head.** I'd run `scripts/ready.sh https://github.com/acme/app/pull/640 --sha 3be1f09c2`. I'm looking for `e2e-safari` as the only `BLOCK`, with threads clean and approvals on that head. If anything else shows up, I report it and don't merge.

**3. Merge through the gate with the override.** I'd re-fetch the PR to confirm it's still open and the head is unchanged. Then I'd run:
```
COORD_READY_OVERRIDE="e2e-safari job deleted in #631; stale required context in branch protection" \
  gh api -X PUT repos/acme/app/pulls/640/merge
```
The hook sees it, logs it to `.coordinator/overrides.log`, and lets it through. Your "just merge it" covers merge authority for this PR.

**4. Expect GitHub to refuse the merge.** The override only clears my local gate. GitHub enforces branch protection server-side and will likely return "required status check e2e-safari is expected." I won't use admin bypass to get past that. The real fix is removing `e2e-safari` from the required checks in Settings → Branches (or the ruleset), which needs a repo admin. If that's you, do it and tell me, and I'll retry the merge. If it's someone else, I'll draft a short note for them for your approval.

**5. After merging.** I'd confirm the merge commit is on trunk and base CI is green, and tell you the override was used and why. I'd also add a task to clean up the branch protection if it's still open.