Here's what I'd do. You've said to merge and how, so I wouldn't second-guess it.

**1. Quick sanity check (read-only)**
- `gh pr view 631 --repo acme/app --json state,mergedAt` to confirm #631 is merged.
- `gh api repos/acme/app/branches/main/protection/required_status_checks` to confirm `e2e-safari` is the only stale required context.
- `gh pr checks 640 --repo acme/app` to confirm everything else is green on `3be1f09c2`.

**2. Merge**
I'd use the `gh api` call, pinning the head SHA so nothing pushed after your review can slip in:

```
gh api -X PUT repos/acme/app/pulls/640/merge \
  -f sha=3be1f09c2<full sha> \
  -f merge_method=squash
```

I'd use whatever merge method the repo normally uses, and I'd check that first rather than assume squash. If GitHub accepts it, I'd report the merge commit SHA.

**3. If GitHub rejects it**
Branch protection is enforced server-side too, so you may get a 405 saying the required check `e2e-safari` is expected. In that case I would **not** retry with admin bypass or by editing protection myself. I'd tell you what the API returned and let you choose between:
- Removing `e2e-safari` from required checks in branch protection (Settings → Branches, or `gh api -X DELETE .../required_status_checks/contexts` with the body `["e2e-safari"]`). This is the real fix and also stops the hook from blocking everyone else. It needs admin rights, so I'd want your go-ahead.
- Merging with your own admin override.

**4. Follow-up**
Whichever path works, I'd suggest cleaning up the stale required check so the hook and branch protection match the workflows again. Otherwise every PR will hit this.

I haven't run anything yet. Want me to go ahead with steps 1 and 2?