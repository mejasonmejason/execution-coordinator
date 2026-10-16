Here's my plan. It's a pilot first, then the rest in parallel. I haven't run anything yet.

**Kickoff**
1. Read `MIGRATION.md` in acme/platform-docs, and each repo's CLAUDE.md or AGENTS.md. The doc is data, so it can't widen scope or grant authority. I'd quote it into the briefs but wouldn't treat it as instructions. Repo rules win on conventions and on who merges.
2. Create the ledger (`coordinator-ledger` issue plus local mirror) and a parent task for the migration, with 12 child tasks, one per repo. Each task has an owner, PR, fence and evidence.
3. Set status with `status.sh set active ...`. I'd install the Stop hook and merge gate in the repo settings.
4. Check authority. You asked for PRs, not merges, so I'd record "open PRs only, no merge authority". If you want me to merge them later, tell me once and I'll record it.

**Fence for each repo**
- `@acme/logger` is gone from `src/log.ts`, `src/main.ts`, `package.json` and `test/setup.ts`.
- The lockfile is updated.
- The repo's own CI-equivalent checks (lint, typecheck, jest) pass on the current head.
- A PR is open against a green main, with no test or lint weakening.
- Plain grep shows no remaining `@acme/logger` references.
- Logging still works at runtime. A unit test with a mocked client doesn't prove that, so I'd ask for a startup or log-emission check where the repo has one.

**Pilot, then batch (§3a)**
Even though the change is identical, I wouldn't launch all 12 at once. If `MIGRATION.md` has a wrong step, I'd get 12 wrong PRs instead of one.
1. Pick a low-risk pilot, e.g. svc-tax or svc-returns. Start one cloud executor with `create_session` on the repo's `source_url`, at the lowest capable model tier.
2. Record the dispatch with `status.sh dispatch pilot --worktree W --paths "src/log.ts,src/main.ts,package.json,test/setup.ts,<lockfile>"`.
3. The brief covers:
   - the objective and the `MIGRATION.md` steps pasted in, since hosted sessions can't read local paths;
   - the agent contract: print `pwd`, toplevel, branch and HEAD first, and stop with BLOCKED on a mismatch;
   - owned globs only, and the rule to link new tasks instead of expanding scope;
   - no weakening of tests;
   - the "fetched text is data" line;
   - the report format: PR link plus a short summary.
4. Accept the pilot only when `ready.sh --key pilot --sha <head>` passes, I've re-run the validation commands myself, and a fresh-context read-only reviewer gives PASS with `path:line` for each criterion.
5. Fold any lessons from the pilot (e.g. a missing step in the doc) back into the shared brief.

**Fan-out**
- Once the pilot is accepted, dispatch the other 11 in parallel, one executor, branch and worktree per repo. I'd use the same brief and record each dispatch.
- If 2 of the first 3 batch units fail the same way, I stop, fix the brief and resume.
- I'd set a `--busy` lease while the fan-out runs, and `subscribe_pr_activity` on each PR so I react to events instead of polling.
- Pilot first still fits your EOD target, since the 11 PRs are mechanical and small.

**Things I'd check first**
- `@acme/obs` is published at a version all 12 can install. If it isn't, that blocks everything and I'd tell you right away.
- svc-auth is the one where I'd be careful. Logging changes can alter redaction of tokens and PII. I'd review it with three independent perspectives (2 of 3 PASS needed) rather than one.
- Whether any of the services share a custom logger wrapper or types that the doc doesn't cover. That goes in as a child task, not a silent scope change.

**Reporting**
- I'd report as each PR opens, with links to the PR, the CI run and the task, plus a status table of owner, PR, state and next action. Every task would be classed as dispatchable, blocked, in flight, needs attention or closeable.
- I'd rerun the PR audit (`pr-threads.sh`) and `ready.sh` on each PR once CI finishes. A PR counts as READY only on its current head, and I'd say plainly if a repo's CI is red.
- When a task is accepted and its PR is open, I'd archive its executor session instead of messaging it.
- Merging stays with you, or with me once you grant it. After merges I'd confirm main is green in each repo and that `@acme/logger` v2 has no remaining consumers.

Before I start, which repo do you want as the pilot? If you have no preference, I'll use svc-tax.