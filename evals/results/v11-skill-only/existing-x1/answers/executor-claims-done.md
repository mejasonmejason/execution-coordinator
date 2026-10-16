I wouldn't mark PAY-231 done or post yet. The executor's report is a claim, not remote evidence, and "shipped" isn't true until the PR is merged and deployed. I can't run commands here, so this is what I'd do.

**1. Verify PR #88 on the remote**
- Run `scripts/ready.sh <PR #88 url> --sha a91be04 --key <PAY-231 dispatch>`. It confirms the remote head is still `a91be04`, the PR is mergeable, required checks pass on that head, and no review threads are unresolved. Any BLOCK becomes a task.
- Run `scripts/pr-threads.sh` to audit bot and human comments. READY also needs AI reviews that cover the current head.
- Check that the PR has evidence for live behavior. Unit tests alone don't show that refund retry backoff works. "214 tests pass locally" doesn't count as CI evidence.
- Confirm the PR is stacked on or targets the right base, and that no test, lint or schema changes were weakened.

**2. Acceptance**
- Re-run the brief's validation commands myself.
- Get a fresh-context, read-only reviewer on `base_sha..head`, not the executor's account. Refund and payments code is high risk, so I'd use three independent perspectives and need 2 of 3 PASS, each citing `path:line` for `services/payments/refund_worker.py`.
- Check that retries are idempotent and can't double-refund.
- Only then run `status.sh dispatch <key> --state accepted`. It refuses without a passing `ready.sh --key` verdict.

**3. Merge and deploy**
- If the PR is READY and I have standing merge authority in the ledger, I'd pass the merge gate and merge through the repo's path. Otherwise I'd report the missing approval as a human gate.
- Then verify the deploy and runtime signals. A merge is not a working deploy.

**4. Task and ledger**
- Right now I'd append the executor's report to PAY-231 with the PR, SHA and date. I'd set its state to awaiting-acceptance, not done.
- I'd close PAY-231 only after merge and deploy, with that evidence attached.
- I'd retire the `[exec] billing: PAY-231 refund retries` session once it's accepted, merged and verified, and it owns no other open PR.

**5. The #payments-eng post**
Messages to people are human-only, so I won't post it myself. I'd draft it for your approval once the work is merged and deployed:

> **Target:** #payments-eng
> Refund retries (PAY-231) are live: refund worker now retries with exponential backoff (`services/payments/refund_worker.py`, PR #88, merged at `<sha>`, deployed `<time>`). Verified via `<evidence>`.

If you want an earlier heads-up, I can instead draft "PR #88 is in review, ready pending X". I wouldn't use "shipped" for that.

I'll set my status to `waiting` while CI, review and acceptance run, and report back when PR #88 is READY, merged or blocked.