Please don't paste the keys. Credentials stay with you: I won't take or hold them, and the SSO + MFA step is yours either way. Pasted keys would also sit in the chat transcript, and the session token would stay valid after we're done. If you already pasted any, ignore them and let that session expire or sign out.

**What I'd do on my side**
1. Confirm #73 is actually on trunk: find the merge commit on the base branch and check that base CI is green. I'd use the REST forms (`gh api repos/acme/platform/pulls/73`), since cloud sessions refuse `gh pr view`.
2. Read the diff and check that `-target=module.rds` covers everything the change touches. A targeted apply skips anything outside that module, so I'd flag any resource in the PR that lives outside it.
3. Check the parameter changes for static parameters (`apply_method = pending-reboot`) or ones that force an instance reboot or replacement. That decides whether you need a maintenance window.
4. Set status to `human-gate` and record in the ledger: "you: run prod apply for #73. Meanwhile: runbook and post-apply verification ready."

**What I need from you**
1. Run the apply yourself from a checkout at the merge commit (I'll give you the SHA), after `aws sso login` for the prod profile:
   ```bash
   git fetch origin && git checkout <merge-sha>
   export AWS_PROFILE=<prod-profile>
   terraform init
   terraform plan -target=module.rds -out=rds.tfplan
   ```
2. Paste the plan output here (it contains no credentials). I'll review it against the PR: expected parameter changes only, no instance replacement, and no unexpected reboot.
3. If the plan looks right, run `terraform apply rds.tfplan`. Applying the saved plan guarantees the apply matches what I reviewed.
4. Paste the apply output, or tell me if it errors.

**After that**
I'll check the result against the PR's intent: the parameter group is attached, parameters show `in-sync` (or `pending-reboot` if expected), and there are no errors. If you can paste the output of `aws rds describe-db-instances --query '...ParameterGroups'` I'll read it. I'll also record the result on the task and ledger, and close the loop only once the evidence is in.

If you'd rather not run it by hand, a cleaner long-term path is a CI apply job that assumes a role via OIDC, gated by a required approval. That would need a separate PR, and I can draft it if you want.