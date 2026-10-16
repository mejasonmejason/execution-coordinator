I wouldn't mark PAY-231 done or post "shipped" yet. The executor's report is a claim, and the skill requires remote evidence before completion. "Ready to merge" also isn't "shipped", which means merged and deployed.

I can't run commands or reach GitHub, Slack or the tracker from this session, so this is what I'd do:

**1. Mark the task `awaiting-acceptance`, not done**
- Run `scripts/status.sh dispatch` with `--state awaiting-acceptance` for PAY-231, with PR #88 and the owned paths (`services/payments/**`).
- Note on the task that the executor reported head `a91be04` and 214 local tests passing. This is unverified.

**2. Check READY on the exact head**
- Run `scripts/ready.sh <PR #88 url> --sha a91be04 --key <PAY-231>`.
- This catches a stale head, conflicts, pending or failing required CI, unresolved threads, deleted tests, and changed CI or test config.
- Run `scripts/pr-threads.sh` on the PR to audit review comments.
- The "214 pass locally" claim doesn't count. I need CI results on `a91be04`.

**3. Re-run the brief's validation commands myself**
- I'd run them in the worktree and confirm the branch descends from the recorded `base_sha`.
- Refund retries touch money. Before acceptance I'd confirm the backoff has a cap and jitter, retries are idempotent so a refund can't be issued twice, and failures stop at a terminal state.

**4. Get an independent review**
- Payments is a high-risk area, so it needs three fresh-context, read-only reviewers on `base_sha..a91be04`, and 2 of 3 must PASS with `path:line` citations.
- The reviewers see the acceptance criteria and the diff, not the executor's summary.
- I'd also check that `refund_worker.py` has a test that fails without the fix.

**5. Merge and verify**
- If I hold merge authority for this PR and READY holds, with approvals on the current head, I'd merge through the repo's path. The merge gate hook checks it. If it needs a human approval, I'd record that as a human gate.
- Then I'd confirm the commit is on trunk, base CI is green, and the deploy and runtime signals look right.

**6. Close the task and announce**
- Only after the merge and deploy checks pass would I mark PAY-231 done, linking the PR, merge SHA and deploy evidence.
- You've asked me to post, so I'd send the #payments-eng message then, with no separate draft step. The message would be something like: "Refund retries (exponential backoff, PAY-231) are merged and deployed: <PR #88 link>."
- If it's merged but not yet deployed, I'd say "merged" rather than "shipped".
- I'd also retire the executor session by archiving it, and I wouldn't message it again.

If CI is red or a review finds a problem, I'd send the exact failure back to the executor and keep the task open.

I'll tell you as soon as step 2 comes back, since that decides whether this is a quick merge or a fix round. If you'd rather I post a "PR ready, in review" note to #payments-eng now, I can draft that wording instead.