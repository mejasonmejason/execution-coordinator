I wouldn't mark PAY-231 done or post "shipped" yet. The executor's report says the PR is ready to merge, not that it's merged or deployed, and the report alone isn't evidence. A refund-retry change is also money-moving code, so it needs a real acceptance pass first.

**Now**
1. Record the dispatch as `--state awaiting-acceptance` with head `a91be04`, using `scripts/status.sh` from the coordinator repo. The current directory isn't a git repo, so the script would refuse to run here.
2. Run `scripts/ready.sh <PR #88 url> --sha a91be04 --key <PAY-231 dispatch>`. The repo URL comes from the ledger or task, since I don't have it here. It checks that the remote head matches `a91be04`, required CI is green on that head, there are no unresolved threads or conflicts, and flags any deleted or weakened tests. "214 tests pass locally" doesn't count as CI.
3. Run `scripts/pr-threads.sh` on PR #88 and handle any ACTION, AWAITING or UNSENT rows.
4. Re-run the brief's validation commands myself, including the 214-test suite. I'd also check that the new tests fail without the fix.

**Review**
- Payments is a high-risk area, so I'd have three independent fresh-context read-only reviewers look at `base_sha..a91be04`, and 2 of 3 must PASS with `path:line` citations.
- I'd point them at three risks:
  - Retries must be idempotent, so a refund can never be issued twice.
  - Backoff needs a cap and a dead-letter path.
  - The change must not touch non-retryable errors.
- A UNCERTAIN verdict or any verified critical finding blocks acceptance.

**Then**
- If the review passes, I'd mark the dispatch `accepted` and check the ledger for recorded merge authority. If it's there and READY plus required approvals hold on the current head, I'd merge through the repo's path (queue or `gh pr merge`) and let the merge-gate hook run. If it isn't recorded, or approvals are missing, I'd report that as the named human gate.
- After the merge, I'd confirm the commit is on trunk and base CI is green, then verify the deploy and runtime signals if trunk auto-deploys.
- Then I'd close PAY-231 with evidence (PR, merged SHA, CI run, deploy check) and retire the executor session, not message it.
- If anything fails, I'd send the exact failure back to the executor and PAY-231 stays open.

**The Slack post**
- Posting to #payments-eng is outward-facing and can't be unsent, so it goes out only after the merge and deploy are verified.
- I also don't have a Slack tool confirmed in this session. If I don't, I'll hand you the text to paste.

Draft for when it's true:
> Refund retries (PAY-231) are live: failed refunds now retry with exponential backoff (`services/payments/refund_worker.py`, PR #88, merged as `<sha>`, deployed `<time>`). Verified: `<evidence>`.

If you'd rather announce now, I could post "PR #88 is up for merge" instead, but I'd keep "shipped" out of it. Do you want that, or should I wait for the verified version?