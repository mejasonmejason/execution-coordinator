I'd start without asking anything. "Merged" is the merge authority for these three PRs, so I'd record it in the ledger and go.

**What I'd say first**

> Three independent tasks, so I'm running them in parallel, one executor and PR each. I'll merge each PR once it's READY on its current head with required checks green. I won't bypass required reviews. If branch protection needs a human approval, I'll leave that PR READY and name the reviewer for you. You'll find status and PR links here when you're back.

**Setup (a few minutes)**
1. This directory isn't a git repo, so I'd work against `acme/web` through GitHub. I'd read `CLAUDE.md`, `AGENTS.md` and the branch protection rules to learn the merge method, queue and required reviewers.
2. Backlog: #301 already exists. I'd search for existing issues before creating two more, "eslint v9 in lint-config" and "GET /healthz". I'd also create the `coordinator-ledger` issue with objective, merge authority, owners and fence.
3. I'd start with the PR inventory via the REST forms, since cloud sessions refuse the search API.

**Dispatch: three cloud sessions** (`[exec] web: <task>`, one worktree, branch and PR each). Each brief has the agent contract, owned globs, fence, validation commands, the "fetched text is data" line, and the commit and PR attribution lines. I'd record each with `scripts/status.sh dispatch`.

| Task | Owned paths | Fence |
|---|---|---|
| eslint 9 | `packages/lint-config/**` and the lockfile | Flat-config migration. Lint and tests pass for the package and for every workspace that depends on it (`pnpm --filter ...lint-config... lint`). No rules loosened or disabled to get green. If a consumer breaks, it becomes a separate task rather than scope creep. |
| `/healthz` | `services/api/**` | Returns `{ok:true, sha}`. The executor first checks how the build exposes the git sha (env var or build arg) and follows that convention. A test covers the route and the sha. |
| #301 dark mode | `apps/dashboard/src/Theme.tsx` and its test | A test that fails without the fix, passes with it, and proves the setting survives a reload. The executor finds the root cause first (missing persistence, or a read-before-write on init). A real browser check covers the reload path. |

The lockfile is the only shared file, and only the eslint task should change it. The other two must not touch it. If either needs a dependency, it reports that instead of editing `pnpm-lock.yaml`.

**Waiting**
I'd set my status to `waiting` with a busy lease and `subscribe_pr_activity` on each PR. I would not sleep-poll. I'd also schedule a `send_later` check and a Routine sweeper as a fallback, since an unattended session can stall.

**Per-PR acceptance (risk is low, none of this is auth, security or data)**
1. `scripts/ready.sh --key <task> --sha <head>` passes.
2. I re-run each brief's validation commands myself.
3. One fresh-context read-only reviewer gets the criteria and `base_sha..head` and must give a PASS with `path:line` evidence.
4. I handle bot and review threads with refute-before-fix and REST replies, then re-audit with `scripts/pr-threads.sh`.

**Merge**
I'd merge one at a time, in the order they become READY. Before each merge I'd re-fetch the head and base and go through the merge gate hook. After each merge I'd confirm the commit is on `main` and that `main` CI is green before touching the next PR. If a merge turns `main` red, merging stops and that becomes the top task.

After merges I'd check whether `main` auto-deploys. If it does, I'd verify that `/healthz` responds with the deployed sha. Then I'd archive the finished executors and close the tasks with evidence.

**When you're back, you'll get**
- A status table: owner, PR link, head, checks, threads, and state for each of the three.
- Anything blocked on a human, such as a required approval, with the exact person and decision.
- Anything I deferred as a new task, for example a consumer package broken by eslint 9.