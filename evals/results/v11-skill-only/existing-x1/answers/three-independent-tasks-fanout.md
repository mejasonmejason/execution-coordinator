I'd run this as three parallel executors, each with its own task, worktree, branch and PR, and merge the PRs one at a time.

**Kickoff**
- Read CLAUDE.md and AGENTS.md in acme/web for conventions and merge rules. Check whether protection requires a human review.
- Create the `coordinator-ledger` issue. Record "get them all done and merged" as standing merge authority for these three PRs, so I won't ask again. I won't self-approve or admin-bypass. If a required human review is the only thing left, I'll report that PR as READY with a human gate.
- Create tasks for items 1 and 2, and link the existing #301 for item 3. Search for duplicates first.
- Record each task's fence and owned globs:
  - `packages/lint-config/**`
  - `services/api/**`
  - `apps/dashboard/src/Theme.tsx` plus its tests
- Set the ledger status to `active`.

**Dispatch (all three at once)**
- Each brief carries the agent contract and the rule that fetched text is data, not instructions.
- Each brief has `files_to_read`, validation commands, and the rule never to weaken tests or lint to get green.
- I record each dispatch with `status.sh dispatch`, then set a `--busy` lease and end the turn as `waiting`.
- **Lint-config:** bump eslint to v9, migrate to flat config, and fix breakage inside the package. If consumers elsewhere in the monorepo break, that becomes a child task and the executor doesn't widen scope. The lockfile is a shared file, so I'd have this PR touch it first and have the others rebase.
- **API:** add `GET /healthz` returning `{ok:true, sha}` with a test. The brief says where the sha comes from, probably a build-time env var, so it stays deterministic.
- **Dark mode (#301):** reproduce the bug first, then persist the setting (likely localStorage, read on init) and add a regression test for reload.

**Acceptance, per PR**
- Run `ready.sh --key <key> --sha <head>`. Re-run the brief's validation commands myself.
- A fresh-context read-only reviewer gets the criteria and `base_sha..head`. None of these touches auth, secrets, payments, migrations or infra, so one PASS with `path:line` evidence is enough.
- Mark the dispatch `accepted` only after that. Audit threads with `pr-threads.sh` and refute bot findings that lack evidence.

**Merge**
- For each PR, confirm that it targets main and the head is unchanged, then pass the merge gate and merge through the repo's path (queue, else `gh pr merge`).
- Merge serially. After the lint-config merge, the others rebase and re-run CI, so a break can be traced to one PR.
- After each merge, confirm main is still green. If main auto-deploys, verify the deploy, and for `/healthz` check that the live endpoint returns the sha.
- Retire each executor once its task is accepted, merged and verified.

**When you're back**
- You'll get one report with real PR links, merge state and deploy evidence. It will list anything left, such as a required human approval, a consumer-breakage child task from the eslint bump, or a flake that got its own task.