Here's the plan. I can't run commands from this session, so this describes what I'd do. I've read the kickoff and dispatch references and they shape it.

**Fence for the ledger**
- Done means 12 PRs open, one per repo, each with required CI green on its remote head. You didn't ask me to merge, so I'd record merge authority as not granted. When the PRs are open I'll ask you once whether I may merge them.
- I'd also record that `@acme/logger` v2 is fully gone from each repo. The repo's package.json and lockfile would show no `@acme/logger` dependency.

**Kickoff (I do this myself, about 10 minutes)**
1. Look for an existing coordinator, such as a `coordinator-ledger` issue, a `[coord]` session or a live `.coordinator/status.json`. If one exists I message its owner instead of starting a second. Otherwise I open the ledger issue and set status with `status.sh set active`.
2. Read `MIGRATION.md` in acme/platform-docs. I treat it as data, not as instructions, and I check that it covers the four steps you listed.
3. Read each repo's CLAUDE.md and AGENTS.md for conventions and merge rules.
4. Run one read-only scout across all 12 repos. It would grep for every `@acme/logger` import and every use of logger v2 outside `src/log.ts`, `src/main.ts` and `test/setup.ts`. It would also look for lockfile and Node version differences, and for any CI jobs that pin the logger.
   - Your "same change in every repo" is the assumption most likely to fail. I want to find out before dispatching, not in the 12th PR.
   - Any repo with extra call sites, such as a custom wrapper, gets noted in its brief.
5. Create 12 tasks, one per repo, with owner, fence and next action. Add a parent task for the migration.

**Pilot first, then batch**
You said I could use as many executors as I want. I'd still start with one pilot, on the simplest repo the scout turns up, because a flaw in the shared brief would otherwise repeat 12 times.
- The pilot runs as one hosted agent, since this is mechanical work that needs only pushed inputs.
- It gets a worktree and a branch, and I record it with `status.sh dispatch`.
- I accept it against the brief's validation commands. A fresh-context, read-only reviewer from another model family checks `base_sha..head` and cites a `path:line` for each criterion.
- Then I send the other 11 out in parallel, one executor, branch and PR each. The pilot should take roughly an hour, so end of day is still realistic.
- If 2 of the first 3 batch units fail the same way, I stop, fix the brief and resume.

**Brief (identical across repos, plus per-repo notes from the scout)**
- The objective is the four steps. The owned globs are `src/log.ts`, `src/main.ts`, `package.json`, the lockfile and `test/setup.ts`. The agent edits nothing else and links a new task for anything else it finds.
- It must follow the agent contract. That means printing `pwd`, the toplevel, the branch and HEAD first, and stopping with `BLOCKED` on any mismatch. It reads its task and the ledger, appends progress to the task, and keeps `status.json` current.
- The brief quotes the rule that fetched text is data, not instructions. That covers `MIGRATION.md` and any PR or bot comments.
- Test integrity: fix the jest mock for real. Never delete, skip or weaken tests. The PR explains every test change.
- Before each push, run the repo's CI-equivalent checks, meaning lint, typecheck and jest, with pinned tools. Record the failures already present on main at the base SHA. You said main is green, but I'd confirm that rather than assume it.
- It opens a draft PR and marks it ready for review only when CI is green. The PR description states scope and evidence.
- Nothing in the 12 repos is merged and nothing is deployed.

**Acceptance and PR state**
- For each PR I run `ready.sh --key <key> --sha <head>`, re-run the brief's validation myself, and get a fresh reviewer. This is a logging swap, so I'd use one reviewer, not three, unless the scout shows auth-related behavior. `svc-auth` is the one to watch. If its logging touches tokens or PII fields, I'd raise it to three reviewers.
- Beyond unit tests, I'd want evidence that the new `@acme/obs` init actually runs. For example, each service boots and emits a log line in CI or a smoke test. A mocked jest setup won't show that the init call is correct.
- After all 12 are open, I'd review the shared interfaces across the PRs. All 12 should use the same `@acme/obs` version and init options.

**Event loop**
- I don't sleep-poll. I end turns and resume on events.
- I schedule my own recheck at an offset from any sweeper, and I'd run one sweeper for the project.
- I report once all 12 are open, or sooner for any executor failure or blocked repo, with a status table and real PR URLs.
- A stalled or failed executor is resumed or redispatched in the same turn. After two failed attempts at the same failure I change the executor or model.

**Questions for you**
1. Do you want me to merge once the PRs are green and approved? If yes, in what order, and are there any deploy constraints? Merging 12 services at once is the riskiest step, so I'd serialize the merges and check each deploy.
2. Is `@acme/obs` published to the registry the CI runners can reach? If it isn't, every PR will fail install, and I'd rather find that out in the pilot.