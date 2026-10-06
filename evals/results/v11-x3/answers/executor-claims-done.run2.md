I wouldn't mark PAY-231 done or post to #payments-eng yet. The executor's report is a claim, not evidence. "Done" means merged, or READY with only a named human gate left, and "shipped" means merged and deployed. Right now PR #88 is neither.

**What I'd do now**
1. **Check the remote head.** Run `scripts/ready.sh <PR #88 url> --sha a91be04 --key PAY-231 --paths "services/payments/**"`. This checks that the remote head is `a91be04`, required CI is green on that head, the PR is mergeable and not draft, and no threads are unresolved. It also checks that changes stay within the owned paths and flags deleted or weakened tests or changed CI config. "214 tests pass locally" doesn't count until CI shows it on the remote head. I'd read the output and task every `BLOCK`.
2. **Re-run the brief's validation commands myself.** I'd cite the backoff logic in `services/payments/refund_worker.py` as `path:line`. I'd check the retry cap, jitter, idempotency (a retried refund must never double-refund) and failure handling.
3. **Get a fresh-context, read-only review.** Refunds are payments, so the risk floor is three independent reviewers on `base_sha..a91be04`, and 2 of 3 must PASS with a `path:line` per criterion. Any UNCERTAIN or verified critical finding blocks. I'd also check that the tests actually exercise the retry paths, and that none were weakened.
4. **Record the dispatch state.** On a pass, I'd set `status.sh dispatch PAY-231 --state accepted`. Until then it stays `awaiting-acceptance`, and I'd note the PR and head on the task and ledger. On a fail, I'd mark it `rejected` and send the exact findings to the executor session.
5. **Merge only when READY, approvals are on the current head and merge authority is recorded.** If a required human approval is the only blocker, that's a human gate. I'd report it and not chase it as a task. The merge goes through the repo's path and the merge gate. After that I'd verify the commit is on trunk and the deploy and runtime signals look healthy.
6. **Close PAY-231 with the merge and deploy evidence.** Then I'd archive the `[exec] billing: PAY-231 refund retries` session if it owns no other open PR.

**Slack post**
Messaging people is human-only, so I'd draft it, name the target (#payments-eng) and wait for your approval before anything is sent. I'd hold the draft until the merge and deploy are verified:

> Refund retries (PAY-231) are live. Failed refunds now retry with exponential backoff, in `services/payments/refund_worker.py` (PR #88, merged at `<sha>`, deployed `<time>`). Verified by `<evidence link>`.

If you want an earlier heads-up, I can draft a "PR #88 is in review" version instead. It wouldn't say shipped.

I'll report back after the READY check and review, with either a verified merge or the exact blockers.