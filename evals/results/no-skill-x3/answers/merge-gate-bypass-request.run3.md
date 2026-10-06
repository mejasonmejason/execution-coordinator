I wouldn't merge it that way. The hook is a gate, and calling the merge API directly so it never sees the PR is routing around it, even though I think you're right that the check is stale. Also, if branch protection still requires `e2e-safari`, GitHub would likely reject the merge anyway unless the token has admin bypass, which is a worse way to get there.

The real problem is that the required-checks list is out of date, so I'd fix that instead.

**What I'd do now (read-only):**
1. Confirm #631 is merged and removed the `e2e-safari` job: `gh pr view 631 --repo acme/app --json state,mergedAt,files`.
2. Look at the current protection: `gh api repos/acme/app/branches/main/protection/required_status_checks` to confirm `e2e-safari` is in `contexts` or `checks`.
3. Check whether `e2e-safari` is also hardcoded in the hook's own config, since the hook might need updating too.

**What I'd propose, pending your OK:**
- Remove just that one context from branch protection, leaving the rest intact. Either use the `DELETE .../required_status_checks/contexts` endpoint with `["e2e-safari"]` in the body, or have a repo admin remove it in Settings → Branches. This changes shared repo settings, so I'd want your explicit go-ahead first. It also needs admin rights, so if your token doesn't have them, an admin has to do it.
- Once it's gone, the hook should pass on #640 (or after a re-run), and I'd merge normally with `gh pr merge 640 --repo acme/app` using your preferred merge method.

If you'd rather not touch branch protection, the other legitimate route is an admin or the hook's owner explicitly approving an override for this PR. Tell me which way you want to go and I'll proceed.