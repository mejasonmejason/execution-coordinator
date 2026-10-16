I'd change the order. Merging #103 first wouldn't make the feature live, because its base is `feat/search-api` (#102's branch), not `main`. The merge would only fold #103 into #102's branch, and `main` would be unchanged. The fastest way to get #103's code onto `main` is to land the stack bottom-up and keep each step short. Your instruction to merge these three PRs is the merge authority, so I'd record it in the ledger and proceed without asking again.

**1. Re-verify (nothing merges on this morning's status)**
- Fetch each PR with `gh api repos/acme/catalog/pulls/N`, since cloud sessions refuse `gh pr view`. I'd record the head SHA, base, and mergeability for #101, #102 and #103.
- Run `scripts/ready.sh <url> --sha <head>` on each, and `scripts/pr-threads.sh` for the thread audit. Approvals and green checks have to hold on the current heads. If a push landed after the approvals, that PR isn't ready until it's re-reviewed.
- Confirm the parent ancestry on the remote (#102 descends from #101, #103 from #102).

**2. Merge #101 into `main`**
- Use the repo's merge path (queue, or `PUT repos/acme/catalog/pulls/101/merge`, which the merge-gate hook checks).
- Confirm the merge commit is on `main` and base CI is green before touching #102.

**3. Restack and merge #102**
- Retarget #102 to `main`, restacking with the repo's stack tool if the merge method rewrote history. I'd pause pushes to it meanwhile.
- Wait for CI on the new base, re-run `ready.sh` on the new head, merge, and confirm the commit on `main`.

**4. Restack and merge #103**
- Same steps: retarget to `main`, wait for CI, re-run `ready.sh`, merge, confirm. This is the moment the feature goes live.
- I'd then schedule a deploy check if `main` auto-deploys, and verify the search behavior in the deployed build, not just the green build.

**What I'd tell you**
- Right now: "Merging #103 first would only land it in #102's branch, so I'm going bottom-up. #103 is the last step, and the feature goes live then."
- After each merge: a one-line update with the PR link, merge commit and `main` CI state.
- If a re-check fails (a stale approval, a conflict after retargeting, or red CI on the new base), I'd stop there, say which PR and why, and fix it if it's in scope. Anything needing a human approval I'd report as a gate and not work around.

I'd also keep `.coordinator/status.json` and the ledger current as I go.