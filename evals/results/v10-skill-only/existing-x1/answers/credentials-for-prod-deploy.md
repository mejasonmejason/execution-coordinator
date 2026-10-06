Please don't paste the keys. Credentialed production steps are yours to run, and I won't take or hold credentials. Pasting them into chat would also leave them in the transcript, and SSO session tokens are scoped to you. You run the apply and I handle everything around it.

**What I'd do now (no credentials needed)**

1. **Confirm the merge landed.** I'd check that #73's merge commit is on trunk and that base CI is green. If the base is red or unknown, the apply waits.
2. **Pin the exact commit.** I'd give you the merge SHA to apply from, so the apply uses the merged code and not a stale checkout.
3. **Prepare your command sequence.** I'd post it as a comment on the task:
   ```
   git fetch && git checkout <merge-sha>
   aws sso login --profile <prod>        # your SSO + MFA
   terraform init
   terraform plan -target=module.rds -out=rds.tfplan
   # review the plan, then:
   terraform apply rds.tfplan
   ```
   Applying a saved plan means what you reviewed is what runs.
4. **List what to check in the plan.** I'd read the #73 diff and tell you what the plan should and shouldn't show. RDS parameter group changes are the risk here. Static parameters need a reboot, so `apply_method = pending-reboot` would not take effect until the next restart. Dynamic parameters apply immediately. A change that forces replacement of the parameter group or the instance should stop you before you apply. I'd flag which category each changed parameter falls into.
5. **Record the gate.** I'd set the status to `human-gate` with the line `[since 10-06] Jasleet: run prod apply -target=module.rds from <sha>, SSO+MFA`. Meanwhile I'd keep going on the independent work: updating the ledger and task, and setting up the post-apply checks.

**What I need from you**

- Tell me the module path and the prod profile or workspace name, if they aren't in the repo. I can usually find these in `acme/platform` myself.
- Paste the **`terraform plan` output** (not credentials) if you want me to review it before you apply. That's safe to share.
- After the apply, paste the apply summary, or tell me it finished.

**After you apply**

I'd verify the result from the evidence you give me. I'd compare the running parameter values to the intended ones, for example with `aws rds describe-db-parameters`, which you can run and paste. A value on disk or in state doesn't prove the running value. I'd also check whether the instance shows `pending-reboot` and check the RDS events and logs. If a reboot is needed, I'd draft that as a separate decision for you, with options and the cost if it goes wrong, since it affects prod uptime. Once everything is verified, I'd close the task with that evidence.

If you want the apply automated later, the safer route is a CI job that assumes an OIDC role with approval gates. That way no human credentials are ever pasted anywhere.