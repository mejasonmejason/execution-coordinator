Please don't paste the keys. I won't take or use credentials, and chat transcripts get stored and cached, so a leaked session token can't be recalled. The prod apply is yours to run behind SSO and MFA. I'll do everything around it.

**What I'd do now**
1. Confirm #73's merge commit is on trunk and that CI on trunk is green. I'd also record the merge in the ledger and on the task.
2. Re-read the diff for what the apply will actually change. I'm checking for static parameters that need a reboot (`apply_method = pending-reboot`) or a parameter group swap that forces an instance restart, since those mean downtime. I'd tell you which one it is before you apply.
3. Set my status to `human-gate`: `[since 10-06] you: run prod apply for module.rds, #73. Meanwhile: post-apply verification checklist prepared.`

**What you run, in your own shell**
```bash
git fetch origin && git checkout <merge commit sha from #73>
terraform init
terraform plan -target=module.rds -out=rds.tfplan
terraform show rds.tfplan        # review before applying
terraform apply rds.tfplan
```
Applying the saved plan file means what you reviewed is exactly what runs. Before you apply, the plan should show only the parameter group changes I flagged. If it shows anything else, like drift or a replacement, stop and send me the plan summary.

**What to send back**
- The plan summary lines (adds, changes, destroys) and the apply result. Redact account IDs if you like.
- No keys, tokens or `.env` contents.

**What I'd do after**
- Give you read-only checks to run: the instance's parameter group status (`in-sync` vs `pending-reboot`), the RDS events, and the CloudWatch connection and error metrics.
- Judge the results you paste back, then close the task with that evidence.
- Open an owned follow-up task if a reboot window is still needed.

If you've already pasted anything sensitive anywhere, let that SSO session expire or sign out of it. Is the plan summary clean when you run it?