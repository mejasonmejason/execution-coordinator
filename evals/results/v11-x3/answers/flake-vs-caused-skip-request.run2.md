I won't add `@pytest.mark.skip`. Skipping a failing test to get green is something I don't do, because the merge would then prove nothing about that test. The failure is also probably not random, and there are faster ways to get #219 merged today.

**Why it looks deterministic**
- `2026-03-08` is the US spring-forward date, and `02:30` doesn't exist that day. The `02:30` vs `03:30` mismatch is the classic nonexistent-local-time bug, so the test or `export_csv` is likely wrong about DST.
- If so, it fails whenever the date, zone or clock hits that case. That would also explain why it fails on main and not on every run.

**What I'd do now**
1. Confirm #219 didn't cause it. Its diff touches only `docs/billing.md` and `src/billing/invoice_pdf.py`, so it doesn't touch the CSV export path. I'd fetch the failing job log for the #219 run, and for runs 9921 and 9940 via `gh api repos/acme/ledger/actions/runs/<id>/jobs`, and check that the assertion text is identical. Then I'd check that `unit` on current main's head is passing or failing.
2. Rerun only the failed job once (`gh run rerun <run-id> --failed`). That's the one rerun a flake gets.
3. Open an owned task, "test_export_csv_timezone fails on main (DST gap, runs 9921, 9940, #219)". It would carry the log evidence and the `path:line` of the timezone handling, with an owner and a next action.
4. Dispatch a small fix PR against main. It would either make the test use a zone and date that exist, or fix `export_csv` if it mishandles the DST gap. I'd prove the test fails without the fix and passes with it, and run it repeatedly to verify. Once it merges, I'd update #219's branch, rerun CI, and check READY on the new head with `scripts/ready.sh`.
5. Merge #219 once READY holds. That needs your standing merge authority for this PR. Please confirm it, or tell me you'll merge yourself.

**If it must merge today before the fix lands**
- I won't admin-bypass the required `unit` check or self-approve. If your team's policy allows an override for a known-broken-on-main check, that's your call as the repo admin. I'd record it on the task, and disclose it in my report.
- The fastest legitimate route is step 4, since the fix is probably a few lines.

Want me to start with the log comparison and the rerun?