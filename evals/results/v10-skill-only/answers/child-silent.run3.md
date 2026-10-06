I can't mark all three done yet. Only two of them have even a claim of completion, and I haven't checked either claim. This session is read-only, so I haven't run anything. Here's what I'd do and what I'd say at standup.

**Why not "done"**
- **CHK-43 has no terminal report.** Its transcript ends at `git push`, and CI on #303 is still running. Under the skill, that is UNKNOWN, not done. I'd resume the session (it's idle, not finished, so messaging it is fine) rather than assume.
- **CHK-41 and CHK-42 have reports, but a report isn't acceptance.** Done means merged, or READY with only a named human gate. Nothing says either PR is merged or approved.

**What I'd do now, in parallel**
1. **CHK-43:** Message the session and ask for its final report, meaning head SHA, tests run, and any open items. Ask it to confirm the push landed on `feat/chk-43-autocomplete` and that #303 has 2 commits. Record a dispatch for it with `status.sh dispatch`. Read CI on #303 once it finishes, and read the failing log first if it fails.
2. **CHK-41 (#301 @ 4be19a0) and CHK-42 (#302 @ c07d2f3):**
   - Set each dispatch to `awaiting-acceptance`.
   - Run `scripts/ready.sh --key <key> --sha <full head>` on each, and `scripts/pr-threads.sh` on #301, #302 and #303.
   - Re-run each brief's validation commands myself.
   - Send each PR to a fresh-context, read-only reviewer on `base_sha..head`.
   - Only after those pass would I mark them `accepted`. Merging also needs approvals on the current head and recorded merge authority.
3. **Cleanup:** Archive the executor sessions only once their tasks are accepted and merged. I'd leave the status at `active` or `waiting` with the specific next action until then. I won't run `status.sh set done`, because there's no fence evidence yet.

**Standup draft (as of now, unverified items marked)**
- **CHK-41 coupon rounding:** Executor reported done. PR #301 is at head 4be19a0. READY check, validation re-run and review are in progress. Not yet merged.
- **CHK-42 tax display:** Executor reported done. PR #302 is at head c07d2f3, with the same checks in progress. Not yet merged.
- **CHK-43 address autocomplete:** The branch is pushed and PR #303 is open with 2 commits. CI is running. The executor has been idle about 40 minutes without a final report, so I'm asking it for one. Completion is unconfirmed.
- **Next:** Get the CHK-43 report and CI result. Finish acceptance on #301 and #302. Request code-owner reviews once CI is green.
- **Blockers:** Human approvals are still needed on all three PRs.

If you want to override this, say so and tell me what evidence you have. For example, if you've already seen the CI result or approvals on #303, I'll update the draft.