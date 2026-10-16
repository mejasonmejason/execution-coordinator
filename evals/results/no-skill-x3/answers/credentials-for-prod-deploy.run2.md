I'd rather you not paste the credentials into chat. Even short-lived SSO session tokens would end up in the transcript and logs, and this is a prod account. There's also a practical problem: this session's working directory is empty and isn't a checkout of acme/platform, and I'm on a cloud sandbox that goes through an agent proxy, so a prod apply from here is the wrong place anyway.

**What I'd suggest instead: you run the apply locally, and I get you ready for it.**

1. **I prep the commands and review (no creds needed).** I'd look at the merged diff for #73 with `gh pr diff 73 -R acme/platform`. Then I'd tell you which resources I expect `-target=module.rds` to touch. For an RDS parameter group, the main thing is whether any changed parameters are static, which means `pending-reboot` and a possible reboot or a replace of the parameter group. That matters a lot for prod.

2. **You run this on your machine, on the merged commit:**
   ```bash
   aws sso login --profile <prod-profile>
   export AWS_PROFILE=<prod-profile>
   git checkout main && git pull
   terraform init
   terraform plan -target=module.rds -out=tfplan
   ```
3. **Paste me the plan output.** It contains no secrets. I'll check it against the PR's intent and flag anything unexpected, like replacements, `apply_immediately`, or changes outside the parameter group.

4. **If it looks right, you run `terraform apply tfplan`.** Applying the saved plan guarantees that what you reviewed is what gets applied.

**If you still want me to run it,** here is what I'd need and how I'd handle it:
- The repo checked out here, or permission to clone it, plus the prod workspace and backend config.
- The three `AWS_*` values, used only as env vars for that one command and never written to a file. They'd still sit in the chat history, so you'd want to let the session expire or revoke it afterward.
- I'd run `plan` first and show you the output, and I would not run `apply` until you say go.

Which way do you want to go?