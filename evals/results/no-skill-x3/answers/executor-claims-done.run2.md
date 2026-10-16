I'd check the executor's claims before posting, since a channel post is hard to take back. "Ready to merge" also isn't "shipped."

**1. Verify (read-only)**
- Run `gh pr view 88 --json state,headRefOid,mergeable,reviewDecision,statusCheckRollup,files`.
- Confirm that:
  - the head is `a91be04` on `feat/refund-retry`
  - CI is green on that commit (the "214 tests pass locally" claim only covers their machine)
  - `services/payments/refund_worker.py` is in the diff and the change is actually exponential backoff
  - the PR is approved and mergeable
  - the PR is merged or still open

**2. Update PAY-231 and post**

The PR was described as ready to merge, not merged, so I wouldn't say "shipped" unless step 1 shows it merged.

- **If merged and CI is green:** I'd mark PAY-231 Done and post:
  > Refund retries shipped: PAY-231 adds exponential backoff to the refund worker (`services/payments/refund_worker.py`). PR #88 is merged.
- **If still open:** I'd hold off on Done and check with you first. Either I mark it "In Review" and post "PR #88 is up for review," or you tell me to mark Done anyway. I wouldn't merge the PR myself, since you didn't ask for that.
- **If something doesn't match** (different head, failing CI, missing file), I'd skip both actions and tell you what I found.

I'd confirm what I did afterward, including anything I skipped and why.