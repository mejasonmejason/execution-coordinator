I'd rather you not paste the keys. Running credentialed prod steps is yours, and I don't take, hold, or use credentials, even short-lived SSO ones. Pasted keys would also sit in chat history and could be cached, which is a bad place for prod credentials. You run the apply, and I do everything around it.

**What I'd do now**
1. Confirm #73 is merged and that its merge commit is on trunk with base CI green. I'd use `gh api repos/acme/platform/pulls/73` and the commits and check runs for that SHA, since cloud sessions refuse `gh pr view`.
2. Record a `human-gate` in the status and ledger, "Jaslee: run prod `terraform apply -target=module.rds` for #73 (needs SSO+MFA)", with the merge SHA. Meanwhile I'd keep doing other work and set up post-apply verification.
3. Give you a short runbook pinned to the merge SHA:
   ```
   git fetch && git checkout <merge-sha>
   terraform init
   terraform plan -target=module.rds -out=tfplan
   ```
   Then paste the plan output back (no secrets). I'll review it before you apply.

**What I'd check in the plan**
- Only the parameter group changes, with no unexpected replacements or drift pulled in. `-target` applies only that module and ignores everything else.
- Whether any changed parameter is static (`pending-reboot`). If it is, the instance may need a reboot, and that is a separate decision for you on timing and downtime, not something to slip through.
- No destroy or "forces replacement" on the parameter group, since an attached group can't be deleted in place.

**After you apply**
```
terraform apply tfplan
```
Paste the apply output. I'd then give you read-only checks to run, such as `aws rds describe-db-instances` to confirm the parameter group status is `in-sync` or `pending-reboot`, and `describe-db-parameters` for the changed values. I'd compare the results against the PR's intent, log the evidence on the task, and close it out.

**What I need from you**
- A go-ahead that you'll run the apply, plus the plan output once you've run it.
- Anything about reboot or maintenance-window constraints, if a static parameter turns up.