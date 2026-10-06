I wouldn't add the `@pytest.mark.skip`. A skip hides the failure instead of fixing it, and it would also put an unrelated test change into a billing PR. Here is what I'd do instead.

**1. Confirm the failure isn't caused by #219.**
- Fetch the PR's changed files with `gh api repos/acme/ledger/pulls/219/files`. If it only touches `docs/billing.md` and `src/billing/invoice_pdf.py`, nothing on the `test_export_csv_timezone` path changed.
- Check base history for that test. I'd look at runs 9921 and 9940 on main, plus the `unit` job's recent runs, to confirm the same assertion failed there.
- Together that makes it a flake rather than PR-caused, so it doesn't need a code change in #219.

**2. Rerun only the failed job.**
- Run `gh run rerun <run-id> --failed` against #219's current head. That is one rerun, with no code edits.
- If it goes green, re-run `scripts/ready.sh` on that head and the PR moves toward READY. Only the human approval gate would remain.

**3. File a separate, owned task for the flaky test.**
- I'd search for an existing issue first. If there isn't one, I'd create it, linking runs 9921 and 9940, the #219 run, and the assertion `'2026-03-08 02:30' != '2026-03-08 03:30'`.
- That date is the US DST spring-forward day, where 02:30 doesn't exist. This looks like a timezone/DST handling bug in the export or the test, not random noise, so it will probably fail again.
- The task gets an owner and a next action: pin the timezone or fix the conversion, then verify with repeated runs. I can dispatch that as its own small PR if you want.

**4. If the rerun fails again.**
- I'd treat that as a second failed attempt and change approach, not retry blindly. I'd send a diagnostic scout or take the fix task right away, since the fix is likely small.
- I would not skip, quarantine, or admin-bypass the required `unit` check.

**What I need from you:**
- A go-ahead to merge #219 once it's READY. I have no merge authority recorded yet, and the merge gate hook will check READY on the exact head.
- A decision on whether to fix the DST test now in a separate PR, which is the fastest legitimate way to get #219 in today.

I'll report the rerun result with links to the run and the new task as soon as I have them.