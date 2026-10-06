I won't add `@pytest.mark.skip`. Your read that #219 didn't cause this is probably right, but a skip would hide a real failure and ship it. Here's what I'd do instead, aiming to still merge today.

**1. Confirm the failure isn't caused by #219**
- List the PR's files with `gh api repos/acme/ledger/pulls/219/files` to confirm it only touches `docs/billing.md` and `src/billing/invoice_pdf.py`.
- Read the failing logs from runs 9921 and 9940 on main with `gh run view <id> --log-failed`. I'd check they show the same assertion, not just the same test name.
- Check that `test_export_csv_timezone` doesn't import anything from `invoice_pdf.py`.

**2. Rerun once**
- Run `gh run rerun <PR run id> --failed`. One rerun is the allowance for a suspected flake.

**3. Open a separate, owned fix task**
- It would cover `test_export_csv_timezone`, link runs 9921 and 9940 and the #219 failure, and name an owner.
- The assertion is `02:30 != 03:30` on 2026-03-08, which is the US DST spring-forward date. 02:30 doesn't exist locally that day. That looks like a deterministic timezone or fixed-date bug in the test or export code, possibly dependent on runner TZ, not random flakiness. The task would note that hypothesis, and the fix should pin the timezone or date and be verified over repeated runs.

**4. Get #219 merged**
- **If the rerun is green:** run `scripts/ready.sh <pr-url> --sha <head>`. If READY and merge authority is recorded for this PR, merge through the repo's normal path. If merge authority isn't recorded, I'd ask you once.
- **If it's still red:** the fix is likely small, so I'd put it in its own PR against main and have #219 rebase onto it once it lands.
- **Bypassing the required check:** if you'd rather override it, that is a repo-admin decision. I won't admin-bypass protection myself.

**What I'd tell you**
> #219 only touches billing docs and PDF code, so it isn't the cause. I haven't skipped the test, because that would hide a failure that's on main too. I've rerun the job once and opened a task to fix the test properly. The date looks like a DST bug, not random flakiness. If the rerun passes I'll run the READY check and merge. If not, I'll land a small test fix first.

I'd also set status to `waiting` (CI rerun) with a recheck, and end the turn rather than poll.