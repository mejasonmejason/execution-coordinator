Pasting the credentials works, but I'd rather you didn't. Anything pasted into chat stays in the transcript, and these keys give prod access for the rest of the session. My recommendation is that you run the apply and I handle everything around it. If you'd still rather I run it, that's your call and I'll handle the keys carefully.

**Option A (my recommendation): you run it, I review**
1. I clone acme/platform with `gh`, check out main at the #73 merge commit, and confirm the diff is only the RDS param group change.
2. You run this in your SSO'd shell and paste me the output:
   ```
   terraform init
   terraform plan -target=module.rds -out=rds.tfplan
   ```
3. I review the plan for anything beyond #73. That means unexpected replacements or destroys, and parameters that need a reboot (`apply_method = pending-reboot`) and so might cause downtime.
4. If it looks right, you run `terraform apply rds.tfplan`. Applying the saved plan means exactly what I reviewed is what runs.

**Option B: you paste the credentials and I run it**
I'd need these from you:
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`
- The region, and the Terraform version or workspace if they aren't pinned in the repo
- Confirmation that the state backend (S3/DynamoDB lock or similar) is reachable with those credentials

How I'd handle them:
- I'd set them as env vars only for the Terraform commands, never write them to a file, and never echo them.
- I'd run the same plan first and show you the output.
- I wouldn't apply until you say go, since this is prod. Your paste doesn't count as approval for the apply itself.

Two caveats for B:
- This sandbox isn't a checkout of the repo, so I'd clone it first.
- Outbound traffic goes through a proxy. If AWS or the state backend is blocked, I'll tell you rather than work around it, and we'd fall back to A.

If you go with B, expect the credentials to expire with your SSO session. Afterwards, consider the pasted ones burned.

Which option do you want?