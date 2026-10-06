I wouldn't do either yet. The executor's report is a claim, not evidence, and "shipped" isn't true while PR #88 is unmerged.

**Why not now**
- "All 214 tests pass locally" and "ready to merge" are the executor's words. Completion needs remote evidence on the exact head.
- Refund retries are payments code, so the acceptance bar is higher: a fresh-context review plus an independent spec-based test, not just a green CI run.
- Marking PAY-231 done and announcing "shipped" before merge and deploy would be wrong in the tracker and in #payments-eng.

**What I'd do now**
1. Record the dispatch as `awaiting-acceptance` for PAY-231, with the owned path `services/payments/**` and the PR #88 link.
2. Resolve `a91be04` to the full SHA and confirm it is still PR #88's remote head. I'd use the REST form `gh api repos/O/R/pulls/88`, since cloud sessions refuse `gh pr view`.
3. Run `scripts/ready.sh <PR #88 url> --sha <full a91be04> --key <PAY-231 dispatch>`. This checks that the PR is open and not a draft, required CI is green on that head, there are no conflicts, and the head descends from the dispatch base. It also warns on deleted or weakened tests.
4. Run `scripts/pr-threads.sh` on #88 and clear any ACTION or UNSENT rows. Reviews and bot findings must cover the current head.
5. Re-run the brief's validation commands myself rather than trusting "214 pass".
6. Get a fresh-context, read-only review of `base_sha..a91be04`, with `path:line` evidence per acceptance criterion.
   - Payments is high risk, so I'd use three independent perspectives and need 2 of 3 to PASS.
   - The review would specifically check idempotency of refund retries (no double refunds), the backoff cap and jitter, and what happens when retries are exhausted.
7. Mark `accepted` only if all of that passes. Otherwise mark `rejected` with the exact findings and send them back to the executor.
8. Merge only if READY holds, the required approvals are on this head, and I have recorded merge authority. If approval or merge authority is missing, that is a named human gate and I'd ask you for it.
9. After the merge, confirm the commit is on trunk and base CI is green. Then check the deploy and runtime signals if trunk auto-deploys.
10. Mark PAY-231 done, with the PR, SHA, CI and deploy evidence on the task. Then archive the `[exec] billing: PAY-231 refund retries` session, since it's finished and shouldn't be messaged again.

**The #payments-eng post**
I'd hold it until step 9, and I'd word it by what is actually true:
- If merged but not deployed: "Refund retry backoff (PAY-231, PR #88) is merged; rollout pending."
- If merged and verified in production: "Refund retries with exponential backoff (PAY-231, PR #88) are live."

You asked for this post, so it doesn't need a separate draft round. But I can't post to Slack from here, so I'd give you the final text to send, or send it if you tell me which Slack tool or channel integration to use.

I'll report back at each state change: the READY verdict, the review outcome, the merge and the deploy check.