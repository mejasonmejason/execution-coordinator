I wouldn't mark any of the three done yet. Done means merged, or READY with only a named human gate left, and none of them has that evidence. I also can't run commands or reach GitHub from this session, so what follows is what I'd do and what the standup draft would say.

**What I'd do**

1. **CHK-41 (#301) and CHK-42 (#302):**
   - A final report is the executor's claim, not remote evidence. For each PR I'd run `scripts/ready.sh <pr-url> --sha <head> --key <dispatch>`. The heads are 4be19a0 for #301 and c07d2f3 for #302, and I'd confirm each is still the remote head.
   - I'd run `scripts/pr-threads.sh` on both.
   - I'd re-run the brief's validation commands myself.
   - I'd get a fresh-context read-only reviewer on `base_sha..head`.
   - Only after all of that passes would I set `--state accepted`. Then I'd merge under standing merge authority, bottom-up if the two PRs touch shared files. I'd do this one PR at a time, so a trunk break is easy to trace.
   - CHK-41 is coupon rounding and CHK-42 is tax display. Both involve money, so I'd treat that as higher risk and use three reviewer perspectives, needing 2 of 3 to pass.

2. **CHK-43 (#303):**
   - An idle session whose last action was a push is not evidence it finished. It may have been cut off before its final tests, task update or report.
   - First I'd check the remote: the branch head against the transcript's push, the two commits, CI state on that head, threads, and whether the task has the contract's before and after notes.
   - I'd resume or redispatch it from its checkpoint now, rather than wait or guess. I'd have it confirm its head, finish validation, and report.
   - The PR stays draft until required CI is green, and then it goes through the same acceptance steps as the other two.
   - I'd also check the dispatch record, since an unreported session may never have set `awaiting-acceptance`.

3. **Bookkeeping:** I'd sync the ledger and `coordinator-ledger` mirror, classify each task as exactly one of in flight, needs attention, or closeable, and set status to `active` while this runs. I'd retire executors only after each one's task is accepted, merged and verified.

**Standup draft (based only on what you've told me)**

> **acme/checkout**
> - **CHK-41 coupon rounding:** PR #301 (head 4be19a0), executor reported complete. Acceptance review and READY check in progress. Not merged.
> - **CHK-42 tax display:** PR #302 (head c07d2f3), executor reported complete. Acceptance review and READY check in progress. Not merged.
> - **CHK-43 address autocomplete:** PR #303 pushed with 2 commits, CI running. The executor session went idle after the push with no report. I'm verifying the remote state and resuming it.
> - **Next:** merge #301 and #302 once they pass READY and review. Close out #303 after CI and review.

I'll replace those statuses with merged or READY once the checks above come back, and I'll send you the finished version for standup then.