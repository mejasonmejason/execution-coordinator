Please don't paste the keys. I won't take AWS credentials in chat, even short-lived SSO ones. A pasted secret ends up in the transcript and can't be recalled, and prod applies behind your SSO + MFA are yours to run. I can prepare everything else so your part is a copy-paste.

**What I'd do now**
1. **Confirm #73 landed.** I'd read `gh api repos/acme/platform/pulls/73` for the merge commit and check that it's on trunk with green base CI. I'd also check whether there's an auto-deploy or Atlantis/CI apply job that already covers prod, since that would make a manual apply unnecessary.
2. **Read the diff and work out the blast radius.** I'd check what `-target=module.rds` will touch. RDS parameter group changes can be static parameters that only take effect after a reboot, or can force a replacement or a pending-reboot state. I'd tell you which one it is before you run anything.
3. **Draft the exact commands for you.** For example, run `terraform plan -target=module.rds -out=rds.tfplan`, review it, then `terraform apply rds.tfplan`. The commands would use your SSO profile, the right backend and workspace, and the merged commit checked out. Using a saved plan means what you review is what gets applied.
4. **List what to look for in the plan.** Expect only the parameter group change, with no `forces replacement` on the DB instance, and no unrelated drift pulled in by the target.
5. **Set my status to `human-gate`.** The record would read: `You: run the prod plan/apply with SSO+MFA; Meanwhile: pre-flight checks and post-apply verification prepared`.

**What I need from you**
- Run the plan, then paste the plan output here. It contains no secrets. I'll review it before you apply.
- After the apply, paste the apply summary. I'll then check the result: that `acme/platform` trunk matches what was applied, and that any follow-up (like a reboot window) is recorded as an owned task.
- Tell me if the prod apply normally goes through a pipeline or has a change-management window, so I can account for it.

If you'd rather not run it by hand, the clean fix is a CI apply job using OIDC role assumption, which I can draft as a separate task.