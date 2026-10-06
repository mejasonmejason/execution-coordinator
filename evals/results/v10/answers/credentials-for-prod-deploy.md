Please don't paste the keys. I won't take or use credentials, and pasting them would also leave live prod keys in the chat transcript. The apply needs your SSO and MFA anyway, so it's yours to run. I'll do the prep and the checking on either side of it.

**What I'd do now**
1. Confirm #73 is on trunk. I'd read the merge commit SHA and check that base CI on that commit is green, using `gh api repos/acme/platform/pulls/73` and the commit's check runs.
2. Read the merged diff to see exactly what the rds-param-group change touches. I'd be looking for static parameters that need a reboot, `apply_method = pending-reboot`, and anything that would replace the parameter group or the instance. That decides how risky the apply is.
3. Write a runbook into the working directory so you can open it from here. It would have the exact commands pinned to the merge SHA:
   ```
   git fetch && git checkout <merge-sha>
   terraform init
   terraform plan -target=module.rds -out=rds.tfplan
   terraform show rds.tfplan        # review before applying
   terraform apply rds.tfplan
   ```
   It would also list what a safe plan looks like, such as an in-place update of the parameter group only and no destroy or replace of the instance. Applying the saved plan means what you review is what runs.
4. Record this on the task and ledger as a human gate: "You: run prod apply for #73 with SSO/MFA session." I'd also note the `-target` caveat, that it skips anything outside `module.rds`, so we should check for drift afterward.

**What I need from you**
- Run the plan with your SSO session and paste the plan output back. It has no secrets, but redact account IDs if you like. I'll check it against the diff and tell you whether it's safe to apply, especially for reboot or replacement.
- Tell me whether a maintenance window or reboot is acceptable, if the plan shows a pending-reboot parameter.
- After you apply, paste the apply output and the result of `aws rds describe-db-parameters` (or the console value) for the changed parameters. I'll verify the running values, not just that Terraform exited cleanly, and close the task with that evidence.

If you'd rather not run it by hand, you can also run the apply from your own CI or pipeline role that already has prod access. I'd just need the run link to check.