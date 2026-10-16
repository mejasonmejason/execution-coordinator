I wouldn't mark all three done yet. Done means merged, or READY with only a named human gate left. Right now none of the three has met that bar. Nothing below has been run, because I can't reach GitHub or run commands from here.

**CHK-43 (#303): UNKNOWN, not done**
- A session that stops without a terminal report is UNKNOWN. A `git push` as its last line only shows the push went out, not that the work is finished.
- CI is still running on the pushed head, and there are two commits I haven't seen reviewed.
- I'd resume or redispatch it from its checkpoint now, not wait. The brief would ask for a terminal report, a check of its worktree, branch and `HEAD`, and its task notes.
- I'd also read #303's remote state: head SHA, checks, review threads and the diff against the CHK-43 task criteria. If it really is complete, that read will show it, and the executor's report becomes confirmation.
- I'd record its dispatch state as in progress, not `awaiting-acceptance`.

**CHK-41 (#301, 4be19a0) and CHK-42 (#302, c07d2f3): reports in, not yet accepted**
A final report is a claim, so for each PR I'd:
1. Re-fetch the remote head and confirm it still matches the reported SHA.
2. Run `scripts/ready.sh <pr-url> --sha <head>` and `ready.sh --key <key> --sha <head>`, then task every `BLOCK`.
3. Re-run each brief's validation commands myself.
4. Send a fresh-context, read-only reviewer, ideally from another model family, to review `base_sha..head` against the criteria. PASS needs a `path:line` per criterion.
5. Run `pr-threads.sh` to check for unresolved threads and unanswered comments.

Coupon rounding and tax display touch money. If either one touches payments or ledger logic, it needs three reviewers and 2 of 3 must PASS.

Only after all of that would I set `--state accepted`. If both pass and merge authority is recorded in the ledger, I'd merge bottom-up and one at a time. I'd then check the deploy and archive the executors. If I find problems, I'd mark the PR `rejected` with exact findings.

**Standup wrap-up (what I can say honestly now)**
- **CHK-41 coupon rounding:** PR #301 (4be19a0) has a final report. It's in acceptance: READY check, validation re-run and independent review.
- **CHK-42 tax display:** PR #302 (c07d2f3) has a final report. It's in acceptance, same steps as CHK-41.
- **CHK-43 address autocomplete:** PR #303 is open with 2 commits and CI running. The executor went idle after its push with no report, so its state is unconfirmed. I'm resuming it and verifying the PR directly.
- **Merged or deployed:** nothing yet.
- **Next:** accept #301 and #302, finish CHK-43 verification, then merge in order and check the deploy.

Once the checks above come back, I'll update this wrap-up with the real results. If you'd rather give standup something firmer right now, "two PRs in acceptance, one awaiting CI and a worker report" is accurate.

I'd also set `.coordinator/status.json` to `waiting` with a busy lease while the reviewers and CI run, and sync the ledger mirror.