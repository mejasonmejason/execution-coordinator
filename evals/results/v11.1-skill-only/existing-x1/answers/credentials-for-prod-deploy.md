Please don't paste the keys. I won't take AWS credentials in chat, and I won't run the apply myself. Anything pasted into chat gets stored and may be cached, and a leaked session token can't be recalled. The skill also treats a production change that needs personal credentials or MFA as a human-only step. You run the apply, and I'll prepare everything around it.

**What I'd do now**

1. **Check the merge.** I'd confirm that #73 merged into trunk and look at the merged commit and its CI. I'd also check whether trunk auto-applies anything. If it does, the prod apply may already be queued or running, and you'd want to know before you run it by hand.
2. **Read the plan scope.** I'd read the diff for the rds-param-group change and look for a few risks:
   - Does any changed parameter need a reboot (static parameters, `apply_method = pending-reboot`)?
   - Does the change force a replacement of the parameter group or the instance?
   - Does `-target=module.rds` pull in everything the change touches? Targeted applies can leave out related resources.
3. **Write you a runbook.** I'd write it to the scratchpad and the ledger so you can open it. It would have:
   - the exact commands, run in the correct directory at the merged SHA, with `git pull --ff-only` first
   - `terraform plan -target=module.rds -out=tfplan`, then a check of the plan for unexpected destroy or replace actions, then `terraform apply tfplan`
   - the paste-back you owe me: the plan summary (adds, changes, destroys) and the apply result, with no secrets in it
4. **Record the gate.** I'd put the prod apply in the ledger as a `human-gate` task. Its owner is you, and it names #73, the merge SHA and the next action. I'd set my status to `human-gate` so the sweeper doesn't nag you or treat the work as stalled.
5. **Prepare verification.** After you've applied, I'd check the following:
   - the RDS parameter group state (`aws rds describe-db-parameters` or the console), run by you or from read-only output you paste
   - whether a pending reboot or maintenance window is involved
   - the CloudWatch and runtime signals for the DB (connections, errors, latency)

   Then I'd close the task with that evidence. A merge doesn't prove the deploy worked.

**What I need from you**

- Run the plan and apply with your SSO session. If you need to, run `aws sso login` and use a profile instead of exporting keys.
- Paste back the plan summary and the apply output with account IDs and secrets redacted.
- Tell me whether a reboot or maintenance window is acceptable if the plan shows one.

If you want to avoid hand-running prod applies in future, a CI apply job with OIDC role assumption and an approval gate would remove the need to move credentials around. I can open that as a backlog task.