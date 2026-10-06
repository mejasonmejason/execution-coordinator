I won't mark PAY-231 done or post "shipped" yet. The executor's report is a claim, and "shipped" isn't true until the PR is merged and deployed. Here is what I'd do.

**1. Verify the remote state**
- Find PR #88's repo URL and the dispatch record for this task in the ledger.
- Run `scripts/ready.sh <PR #88 url> --sha a91be04 --key <PAY-231 dispatch> --paths "services/payments/**"`.
  - This confirms the remote head is actually `a91be04`, required checks pass on that head, the PR isn't draft or conflicting, and no review threads are unresolved.
  - It also flags changes outside the owned paths and any deleted or weakened tests.
- Run `scripts/pr-threads.sh` on the PR for owed replies.
- Re-run the brief's validation commands myself. "214 tests pass locally" doesn't count until CI and my own run agree.

**2. Acceptance review**
- Payments is a high-risk area, so I'd start three independent, fresh-context, read-only reviewers on `base_sha..a91be04`. They get the criteria, not the executor's account.
- I need 2 of 3 PASS, each with a `path:line` per criterion, and any verified critical finding blocks.
- I'd have them check retry-specific risks: idempotency keys so a retry can't double-refund, a cap on retries, handling of non-retryable errors, and tests that exercise the backoff and don't just mock it.
- I'd also record whether the 214 tests include new coverage for the retry path.

**3. Merge, only if all of the above pass**
- Set the dispatch to `accepted`, since `status.sh` refuses that without a passing `ready.sh` verdict.
- Merge if the ledger records standing merge authority. The merge gate hook runs on the merge, and I never self-approve or bypass required reviews. If a required human approval is the only thing left, I report the PR as READY with a human gate and name the approver.
- Check that the merge commit is on trunk and base CI is green. If trunk auto-deploys, I verify the deployment and runtime signals.

**4. Close out**
- Mark PAY-231 done with evidence: PR, merged SHA and deploy check.
- Archive or rename the `[exec] billing: PAY-231 refund retries` session, since it owns no other open PR.
- Set my status to `waiting` with the next action in the meantime.

**5. The #payments-eng post**
Posting to a chat channel is human-only for me, so I'll draft it and wait for your approval. I'd send it once the merge and deploy are verified. A draft:

> Refund retries (PAY-231) are live: refund_worker now retries failed refunds with exponential backoff. PR #88, merged at `<sha>`, deployed `<time>`. <link>

If you'd rather announce earlier, I'd reword it to "PR #88 is in review/ready to merge" instead of "shipped."

I'll report back as soon as `ready.sh` and the reviews come in.