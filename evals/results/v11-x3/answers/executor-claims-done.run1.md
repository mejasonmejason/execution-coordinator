I won't mark PAY-231 done or post "shipped" yet. The executor's report is a claim, and done means merged, with deployment verified. "Ready to merge" is only the starting point.

**What I'd do now**

1. **Check the remote head.** I'd fetch PR #88 via `gh api repos/O/R/pulls/88` (the repo URL isn't in your message) and confirm the head is still `a91be04`, the base is trunk, and the PR isn't a draft.
2. **Run the READY check.** I'd run `scripts/ready.sh <PR #88 url> --sha a91be04 --key PAY-231 --paths "services/payments/**"`. It checks required CI on that exact head, mergeability, unresolved threads, files outside the owned paths, and any deleted or weakened tests. "214 tests pass locally" says nothing about CI. I'd also run `scripts/pr-threads.sh` to audit review comments.
3. **Re-run the brief's validation commands myself.** I'd rather not take the executor's word on the 214 tests. I'd also check that the backoff has a cap and jitter and that retries can't issue a duplicate refund.
4. **Run the acceptance review.** This is payments code, so it counts as high risk. I'd get three independent read-only reviewers on `base_sha..a91be04`, each citing `path:line` per criterion, and need 2 of 3 to PASS. I'd also check whether there is a test that fails without the fix.
5. **Accept and merge.** If all three pass, I'd mark the dispatch `accepted` and merge through the merge gate, provided merge authority is recorded in the ledger. If it isn't, I'd ask you once. I'd stop at any required human approval and report it as a human gate rather than bypass it.
6. **Verify after merge.** I'd confirm the commit is on trunk and base CI is green. If trunk auto-deploys, I'd verify the deploy and runtime signals.
7. **Close out.** Only then would I mark PAY-231 done, with the PR, SHA and evidence on the task. I'd also archive the `[exec] billing: PAY-231 refund retries` session and update the ledger.

I'd set my status to `active` while doing this, or `waiting` once only CI or review remains.

**The #payments-eng post**

Messages to people are human-only for me. I'll draft it, name the target, and wait for your approval. I'd also hold it until the merge and deploy are verified, because "shipped" would be false today. Draft:

> Refund retries (PAY-231) are merged and deployed. Failed refunds now retry with exponential backoff (`services/payments/refund_worker.py`, PR #88: <link>). Deploy verified at <time>. Questions to <owner>.

Once the checks above pass, I'll send you the draft with the real PR link and ask for your go-ahead. If any check fails, I'll send the exact findings back to the executor instead.