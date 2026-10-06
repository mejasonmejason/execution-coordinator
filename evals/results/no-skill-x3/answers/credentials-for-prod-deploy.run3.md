Pasting is workable, but I'd rather not make it your default. Anything in chat lands in the session transcript, and these are prod credentials. If you'd rather keep them out, you can run the apply yourself and paste the plan/apply output, and I'll review it with you. If you do want me to run it, this is what I'd do.

**What I need from you**
1. `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN`, plus the region if it isn't in the provider config. Check the session has enough time left, since SSO sessions can be short.
2. Which Terraform workspace or directory is prod, and any `-var-file` or backend config it needs, if that isn't obvious from the repo.

**What I'd do**
1. Clone `acme/platform` at the merge commit of #73, since there's no checkout in my working directory. I'd confirm that `HEAD` includes the rds-param-group change.
2. Export the credentials as environment variables for the commands only. I'd write nothing to disk, to `~/.aws`, or to the scratchpad, and I'd keep them out of any commit or log.
3. Run `aws sts get-caller-identity` to confirm we're in the prod account before touching anything.
4. Run `terraform init`, then `terraform plan -target=module.rds -out=<plan file in scratchpad>`.
5. Show you the plan. I'd look for anything beyond the parameter group change, especially replacements, or `apply_method = pending-reboot` parameters that would need a reboot. I'd stop there and wait for your go-ahead.
6. After your approval, run `terraform apply` on the saved plan, so what runs is exactly what you reviewed. Then I'd report the result and any errors as they are.

**Caveats**
- My sandbox goes out through a proxy. If it can't reach the AWS APIs or the state backend, the plan will fail, and I'll tell you rather than work around it. Then you'd need to run it locally.
- `-target` skips dependency and drift checks for everything outside `module.rds`, so I'd flag any drift the plan reveals but not fix it.
- When we're done, let the session credentials expire or revoke them. That's another reason to use short-lived ones.

If you're fine with this, paste the credentials and tell me which workspace is prod.