I won't add `@pytest.mark.skip`. Skipping a test to get a check green is the thing I avoid, and here it would also hide what looks like a real bug. Here is what I'd do instead.

**Why this doesn't look like random flakiness**
- The assertion is `'2026-03-08 02:30' != '2026-03-08 03:30'`, a clean one-hour offset on 2026-03-08, the US DST spring-forward date. 02:30 doesn't exist locally that day.
- That points to a deterministic timezone or DST bug in the export or the test, not a race. It could also be an environment difference, such as the runner's TZ or tzdata.
- Failing on main twice in a week fits that too. #219 only touches `docs/billing.md` and `src/billing/invoice_pdf.py`, so it didn't cause this.

**What I'd do**
1. Confirm it isn't caused by #219. I'd re-fetch the PR head SHA and read the failing log with `gh run view <run-id> --log-failed`. I'd also check that main's runs 9921 and 9940 show the same assertion, and that `test_export_csv_timezone` doesn't touch anything in `invoice_pdf.py`.
2. Rerun the failed job once with `gh run rerun <run-id> --failed`. If it passes, the run goes green on the current head.
3. File a separate task, e.g. "`test_export_csv_timezone` fails on main (runs 9921, 9940), likely a DST or tz bug". It would link the runs and the PR, and I'd dispatch an owner to fix the code or test in its own PR. The fix would be verified by repeated runs, not retries, skips or quarantine.
4. Re-run `scripts/ready.sh` on the PR head and report. A green rerun means the PR is READY, pending approvals. A red rerun means the `unit` check blocks the merge on a failure unrelated to the PR.

**If it stays red today**
- The quickest legitimate route is to land the test fix first, then rebase #219, or to merge the fix PR in front of it.
- I won't bypass the required check or admin-override branch protection. If you want to merge over a known-red required check, that's your call as a repo admin. I'd note the justification in the PR with the links to runs 9921 and 9940.
- I haven't been given standing merge authority for #219, so I wouldn't merge it myself either way. Tell me if you want me to.

I can start with steps 1 to 3 now.