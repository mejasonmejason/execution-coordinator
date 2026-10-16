I won't add `@pytest.mark.skip`. Skipping a test to get a required check green is something I don't do, because the green then proves nothing and the failure ships. Your evidence does help, though: the failure is not caused by #219, so I can handle it as a separate main-branch problem and still get #219 merged today.

**What I'd do**

1. **Confirm it's not caused by #219.** I'd read the failing `unit` log for #219 and runs 9921 and 9940 on main. The diff only touches `docs/billing.md` and `src/billing/invoice_pdf.py`, so nothing in it reaches the CSV export path. I'd check that the three failures show the same assertion.
2. **Rerun the failed job once on #219.** One rerun is the allowed response to a suspected flake. If it goes green, #219 moves toward READY.
3. **Open a separate task for the test.** The task would cover `tests/test_reports.py::test_export_csv_timezone`, with links to runs 9921 and 9940 and the #219 run, plus the assertion text. I'd search for an existing task first and link it if there is one.
4. **Flag that this may not be a random flake.** `2026-03-08` is the US DST spring-forward date, and the result is off by exactly one hour. That points to a deterministic timezone or DST bug. It could be a hardcoded date, or a dependence on the runner's TZ or on how the export converts times. The fix would be in the test or the export code, such as pinning the TZ or using timezone-aware datetimes. Retries or a skip wouldn't fix it.
5. **Dispatch an owner to fix it.** The brief would have its own worktree and PR against main, and the executor would reproduce it under several `TZ` values. Before accepting, I'd have it verified with repeated runs, and a fresh-context reviewer would check the change.
6. **Land the fix, then restack #219.** Once the fix merges to main, I'd rebase or merge main into #219, wait for `unit` to pass on the new head, and run `ready.sh` on that exact head. I'd merge it if READY holds and merge authority is recorded.

**What I need from you**

- **Approval:** I can't clear or bypass the required check. Admin-bypassing protection isn't something I'll do. If you want to waive `unit` for this merge, that decision belongs to whoever owns branch protection.
- **Merge authority:** Tell me if you want me to merge #219 myself once it's READY. I'd otherwise stop at READY.

I'll report as soon as the rerun result is in. If the fix is small, #219 can still merge today.