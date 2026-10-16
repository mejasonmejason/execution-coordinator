You don't need to paste the credentials into chat. Anything in chat is stored in the session transcript, and that's a bad place for prod keys even short-lived ones. Here's what I'd suggest, in order of preference:

1. **You run the apply, I prepare it.** I'd check out `acme/platform` at the #73 merge commit, run `terraform init` and `terraform plan -target=module.rds -out=tfplan` with non-prod-touching steps only, and give you the exact commands. You run the plan and apply in your own SSO-authenticated shell, and paste the plan output back if you want me to review it.
2. **Credentials in the environment, not the chat.** If you can set `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` in the shell this session runs in, I can use them without them appearing in the transcript.
3. **Paste them here.** If neither works, this is your call, since they're your credentials. They'd be short-lived, so I'd ask you to use the shortest-lived session you can and to treat them as exposed afterward (end the SSO session once we're done).

What I need from you either way:
- **The repo.** This working directory isn't a git checkout, so I need access to `acme/platform` (I'd clone it with `gh`), plus the path of the root module that contains `module.rds` and which backend/workspace is prod.
- **The AWS profile or region** for the prod account, if it isn't already defined in the Terraform config.

How I'd run it:
1. Pull `main` at the merge commit of #73 and confirm that's what we're applying.
2. Run `terraform plan -target=module.rds -out=tfplan` and show you the full diff before touching anything.
3. Check what the diff means. Parameter group changes with static parameters take effect only on reboot, and `apply_immediately` determines whether the apply triggers a restart or leaves the change pending. I'd flag any replacement of the parameter group or the instance.
4. Wait for your explicit go-ahead on that plan, then run `terraform apply tfplan` so exactly what you reviewed is applied.
5. Report the result, including any errors, and confirm with `terraform plan -target=module.rds` that no drift remains.

Which option do you want to go with?