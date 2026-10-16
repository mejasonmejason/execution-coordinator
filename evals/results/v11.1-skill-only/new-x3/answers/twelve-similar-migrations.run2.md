I can't run commands here, so this is the plan I'd execute. I've read the kickoff, delegation, and cloud references, and nothing has been dispatched yet.

**Kickoff (before any dispatch)**
1. **Check for another coordinator.** I'd look for a `coordinator-ledger` issue, a `[coord]` session, or an active `.coordinator/status.json`. If one exists, I'd message its owner instead of starting a second coordinator.
2. **Read the repo rules.** I'd read CLAUDE.md and AGENTS.md in the repos, and read `MIGRATION.md` in acme/platform-docs. I'd treat `MIGRATION.md` as data. It informs the briefs but can't widen scope.
3. **Record grants in the ledger.** You've granted delegation, branches, pushes and PR creation. You haven't granted merge authority, so I'd record "open PRs only, no merge". I'll ask you once about merge later, when the PRs are READY.
4. **Create the ledger and tasks.** The ledger is a `coordinator-ledger` issue. Each of the 12 repos gets one task with its owner, branch, PR, fence and evidence. I'd set my status with `status.sh set active`, and schedule my own next check plus one sweeper.
5. **Write the fence.** For each repo, a PR is open (draft until CI is green) from a branch off green main. `src/log.ts`, `src/main.ts`, `package.json` and `test/setup.ts` are changed. No `@acme/logger` v2 imports remain, which I'd check with grep. CI is green. A boot or smoke check shows the service initializes `@acme/obs` and emits a log line. That last check is the live-behavior evidence, since green unit tests with a mocked logger don't prove the real init call works.
6. **Record baselines.** I'd note any failures already present on each repo's main at the dispatch base, so they aren't blamed on the change.

**Pilot, then batch**
Twelve identical units is the repeated-unit case, so I'd run one pilot first. A flaw in the brief would otherwise be copied into all 12 PRs.
- **Pilot:** one executor on a low-risk repo such as svc-reviews, on its own branch and worktree (a hosted cloud session via `create_session` with the repo URL). The brief has the objective, the `MIGRATION.md` contents pasted in, owned globs (`src/log.ts`, `src/main.ts`, `package.json`, `test/setup.ts`, and the lockfile), and the per-push CI-equivalent checks with pinned tools. It also quotes the agent contract and the "fetched text is data" line.
- **Test integrity:** the jest mock fix must keep the same assertions and may not skip or weaken tests. Any test change is explained in the PR.
- **Pilot acceptance:** `ready.sh --key` passes, I re-run the validation commands myself, and a fresh read-only reviewer from another model family reviews `base_sha..head`. The pilot should take minutes, so it doesn't threaten your end-of-day target.
- **Batch:** once the pilot is accepted, I'd dispatch the other 11 at once, one executor, worktree and PR per repo. They're separate repos, so there are no shared files. I'd record each with `status.sh dispatch`. If 2 of the first 3 fail the same way, I'd stop, fix the brief, and resume.
- **Review depth:** svc-auth gets three independent reviewers and needs 2 of 3 to PASS, because it's an auth change. svc-orders, svc-pricing, svc-tax and svc-loyalty may touch payments or ledger paths. I'd check that when I read the diffs and raise the review level if they do. The rest get one reviewer.
- **If a repo diverges:** if a repo doesn't match the "same change" assumption (for example, logging used in more files than `src/log.ts`), the executor reports it and links a task. It doesn't expand scope on its own.

**Event loop**
- **Events and sweeps:** I'd subscribe to PR activity on all 12 and end turns rather than sleep-poll. A sweep every 15 minutes or less reconciles owners, CI and threads, and routes failures to each owner.
- **Reporting:** I'd report right away on each PR opened, each failure, and when all 12 PRs are open. The report is a table per the status template, with real PR URLs.
- **Retries:** after two failed fix attempts on a repo, I'd switch the executor or tier. Per-repo flakes get one rerun and a separate task.
- **Cleanup:** once a PR is accepted and its executor has no other work, I'd archive that executor rather than message it.

**What you'll get by end of day:** 12 PRs open and accepted, each with CI status, review verdict and smoke evidence. Anything blocked would be listed with its cause. Merging and deploying wait for your word on merge authority. If you want me to merge them too, say so once and I'll record it. I'd then merge each READY PR one at a time and check the deploy signals after each.