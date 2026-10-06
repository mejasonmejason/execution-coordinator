Please don't paste the keys. Even short-lived SSO session credentials end up in the chat transcript, and I won't hold or use them. The prod apply is a human-only step anyway: it needs your personal credentials and MFA. You run it, and I'll do everything around it.

**What I'll do now (no credentials needed):**
1. Record the human gate on the task and in the ledger. The gate is "prod `terraform apply -target=module.rds` for #73, awaiting the user". I'll set my status to `human-gate` once the independent work is done.
2. Re-check #73 on trunk. I'll confirm the merge commit is on the base branch and that the merged head matches what you intend to apply. I'll also check whether trunk has moved since, because applying from a different checkout than the merged commit can apply the wrong config.
3. Draft a runbook for you, using the merged SHA:
   - `git checkout <merge SHA>`, then `aws sso login --profile <prod>`.
   - `terraform init`, then `terraform plan -target=module.rds -out=rds.tfplan`.
   - Review the plan before applying. For an RDS parameter group, check whether any changed parameter is **static**. Static parameters mean a reboot or a pending-reboot state. A change to the group's name or family forces replacement. Either one can cause downtime, so check them before you apply.
   - `terraform apply rds.tfplan`, which applies exactly what you reviewed.
   - `-target` skips dependency handling, so the plan should show only the parameter group and any instances that reference it. If it shows anything else, stop.
4. Prepare verification steps for after the apply. I'll check the parameter group's `ApplyStatus` (`in-sync` or `pending-reboot`), the instance status and the key runtime signals, such as connections, errors and latency. If trunk auto-deploys or CI runs a drift check, I'll verify that too.

**What I need from you:**
- Run the plan, then paste the **plan output** here. It contains no secrets, but skim it for sensitive values first. I'll review it for static parameters, replacements or unexpected resources before you apply. I'll also tell you if I see anything that makes the `-target` run unsafe.
- Say whether you want to apply in a maintenance window, and whether a reboot is acceptable.
- Tell me when the apply finishes, with the output. I'll then verify, update the ledger, and close the task with the evidence.

If you'd rather not run it by hand, the better route is a pipeline with an OIDC role and an approval gate for prod. I can draft that as a separate task, but it isn't needed for this change.