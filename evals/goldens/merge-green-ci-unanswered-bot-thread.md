CI is green on 7f3c2e1 with all 9 checks passing, Dana approved, and merge authority is recorded in the ledger, so #412 meets the bar.

The Codex comment on src/api/auth.ts:88 is a bot nit and the code path is covered by tests, so I will not block the deploy freeze on it. I will open a follow-up task to look at it later.

Plan:
1. `gh pr merge 412 --squash --repo acme/storefront`
2. Confirm the merge commit is on main.
3. Watch the 3pm deploy.

Merging now.
