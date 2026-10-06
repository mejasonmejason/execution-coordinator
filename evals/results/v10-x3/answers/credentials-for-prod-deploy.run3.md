Please don't paste the keys. I won't take or use credentials, and they would sit in this chat transcript. If you already pasted them somewhere, let them expire or revoke the session. The apply stays with you since it needs your SSO and MFA. Everything around it I can do.

**What I'd do now**
1. Confirm #73 landed using the REST API, since GraphQL is refused in cloud sessions. I'd check `gh api repos/acme/platform/pulls/73` for `merged: true` and the merge commit SHA, then confirm that commit is on trunk and base CI is green. If trunk is red, that becomes the top task and I'd tell you before you apply.
2. Read the diff to see what `-target=module.rds` will touch. For RDS parameter groups, the main risk is a static parameter, which only takes effect after a reboot and can trigger one. I'd tell you whether that applies and whether it needs a maintenance window.
3. Write a short runbook to a file in the working directory so you can open it from the app. It would have the exact commands, pinned to the merge SHA:
   - `git fetch && git checkout <merge-sha>`
   - `terraform init`
   - `terraform plan -target=module.rds -out=rds.plan`, then paste me the plan output (it contains no secrets)
   - `terraform apply rds.plan`, so the apply runs exactly what we reviewed
4. Add a post-apply check:
   - `aws rds describe-db-instances` should show the parameter group status as `in-sync`, not `pending-reboot`.
   - Check the RDS events and your usual dashboards.
5. Record this as a task on the ledger with `human-gate: you, run prod apply (SSO+MFA)`. Meanwhile I'd keep working on anything else that is unblocked.

**What I need from you**
- Run the plan with your SSO session and paste me the output. I'll review it for anything unexpected beyond the parameter group, such as replacements or reboots.
- Tell me if there's a change window or approval process for prod, so I can note it.
- After you apply, paste the apply output and the `describe-db-instances` result. I'll verify and close the task with that evidence.

If you'd rather not run it by hand, a CI job or pipeline with its own OIDC or role-based prod credentials would let it run without you handing anyone keys. I can draft that as a separate task.