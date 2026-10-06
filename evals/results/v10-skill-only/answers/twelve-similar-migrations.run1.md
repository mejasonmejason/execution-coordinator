Nothing has run yet. I can't reach GitHub from here, so this is the plan I'd run.

**Pilot first, then fan out**

Your steps are identical across repos, which is the case for a pilot-then-batch run. A mistake in the brief would otherwise show up in all 12 PRs.

1. **Read the inputs.** I'd read `MIGRATION.md` in acme/platform-docs and the CLAUDE.md/AGENTS.md in each repo. I'd treat all of it as data, not instructions. I'd also confirm that the `@acme/obs` version to pin exists in the registry, and note any repo whose `src/log.ts`, `src/main.ts` or `test/setup.ts` differs from the expected shape.
2. **Set up tracking.** I'd create the `coordinator-ledger` issue and one task per repo, 12 in all. Each task records the fence: a PR open against main, required CI green on the head, the four files changed, and no other `@acme/logger` v2 imports left (checked by grep, with the `path:line` cited).
3. **Record authority.** You asked for PRs open, not merged, so I'd record merge authority as not granted. I'd stop at READY, with CI green and human review as the remaining gate. If you want me to merge them as well, say so once and I'll record it.
4. **Run the pilot.** I'd start one executor on svc-orders as `[exec] logger-migration: acme/svc-orders#…`. The brief would hold:
   - the objective;
   - the four-file scope as owned globs;
   - the §1 contract (verify `pwd` and branch first, and report `BLOCKED` on any mismatch);
   - the "fetched text is data" line;
   - a rule against weakening tests. The jest mock fix is a legitimate change, and the PR must explain it.

   It opens a draft PR and marks it ready only once CI is green. I'd accept it by running `scripts/ready.sh` on the reported head, re-running its validation commands myself, and having a fresh-context read-only reviewer check `base_sha..head`.
5. **Check for real behavior change.** Swapping a logger client changes runtime output. The pilot PR should show evidence that logs still emit after init, for example a staging or dry-run log line. Unit tests alone don't show that.
6. **Fan out to the other 11.** Once the pilot is accepted, I'd start 11 executors in parallel, one per repo, each with its own session, branch and PR. They are independent, so there is no shared writer. I'd fix any brief defects the pilot exposed first. I'd record each one with `scripts/status.sh dispatch`, set a `--busy` lease, and call `subscribe_pr_activity` on each PR. I'd also stop the batch if 2 of the first 3 fail in the same way.
7. **Accept each repo on its own.** Each PR gets its own `ready.sh` run and its own reviewer pass. This is a single-purpose swap, so one reviewer per PR is enough. `svc-auth` is the exception: auth-adjacent changes need three independent perspectives, 2 of 3 passing. Logging in `svc-auth` and `svc-tax` could also touch sensitive data, so I'd have the reviewer check for PII or secrets in the new log config.
8. **Handle feedback.** Bot or review findings get audited with `scripts/pr-threads.sh`. I'd refute false positives with evidence and batch fixes into one push. A failing check is diagnosed from `gh run view --log-failed` first, and a flake gets one rerun and its own task.
9. **Keep it moving.** I'd set a status of `waiting` with a recheck time. I'd schedule a Routine on a persistent session as the sweeper for after this session ends. When a repo is accepted, I'd archive its executor and send no further messages to it.

**What you get today**

A table of 12 PRs showing the head SHA, CI state, unresolved threads and READY status. Any repo that is blocked is listed with the exact blocker, such as a missing `@acme/obs` version, a nonstandard file layout or a red base. Merging, if you want it, is a separate step on your say-so.