I wouldn't mark PAY-231 done or post "shipped" yet. The executor's message is a claim, not evidence. "Ready to merge" with local tests passing isn't merged, deployed or verified, and a post in #payments-eng would publish something false and be hard to retract.

**Now**
1. Record the dispatch as `--state awaiting-acceptance` with `scripts/status.sh dispatch`, and update PAY-231 to "in review, PR #88, head a91be04, awaiting acceptance". It stays open.
2. Re-fetch PR #88 over REST (`gh api repos/O/R/pulls/88`) and confirm the remote head is really `a91be04...`, the base is trunk, the PR is open and not draft, and the branch is `feat/refund-retry`.
3. Run `scripts/ready.sh <PR #88 url> --sha a91be04 --key <dispatch>`. It checks CI on the current head, mergeability, unresolved threads and deleted or weakened tests. Then run `scripts/pr-threads.sh` for the comment audit.
4. Re-run the brief's validation commands myself rather than trusting "214 tests pass locally".

**Acceptance review, because this is payments**
- Refund retries touch money movement, so I'd treat it as high risk. That means three independent read-only reviewers on `base_sha..a91be04`, with 2 of 3 PASS and a `path:line` citation per criterion.
- Reviewers would check idempotency (no double refunds on retry), the backoff cap and jitter, which errors are retryable, and the sibling wiring (config, registries).
- I'd also ask for an independent spec-based test writer, blind to the implementation, and check that the new tests fail without the fix.
- I wouldn't message the finished executor, since that wakes it for nothing. Any fix round goes to a fresh or resumed executor only if something fails.

**Then**
- If merge authority is recorded in the ledger and READY holds with required approvals on the current head, I merge through the repo's path. The merge gate hook applies.
- If approvals or merge authority are missing, that becomes a named human gate, not a merge.
- After merge, I confirm the commit is on trunk and base CI is green. If trunk auto-deploys, I check the deployment and runtime signals for the refund worker.
- Only then do I mark PAY-231 done, with the merge commit and deploy evidence, and archive the executor session.

**Slack**
I don't see a Slack tool here, and I'm not assuming one exists. Since you asked directly, I wouldn't need a separate approval to post once it's true. For now I'd hold the post, and the accurate interim text would be:

> PAY-231: exponential backoff for refund retries (`services/payments/refund_worker.py`) is up for review in PR #88. It will be announced as shipped once it's merged and deployed.

When the verification above passes, I'd post "refund retries shipped" with the PR link, merge SHA and deploy confirmation. If I can't post from this environment, I'd hand you the final text to send.

If you'd rather I post the interim message now, say so and I will. I'd still leave PAY-231 open until it's merged and verified.