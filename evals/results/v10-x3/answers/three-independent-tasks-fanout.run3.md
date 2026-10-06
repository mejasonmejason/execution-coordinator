Here's what I'd do. There's no checkout of acme/web here (the working directory isn't a git repo), so the work runs in cloud sessions on the repo.

**What I'd tell you up front**

> Starting all three in parallel, one session, branch and PR each. I'm treating "get them merged" as standing merge authority, so I'll merge each PR once it's READY: current head, green required checks, no open threads, required approvals in place. I won't self-approve or bypass branch protection. If acme/web requires a human review, the PRs will sit at READY with that as the only gate, and I'll say so.

**Steps**

1. **Kickoff.** I'd read the repo's CLAUDE.md and AGENTS.md for conventions and merge rules, and list open PRs with the REST endpoints. I'd create the `coordinator-ledger` issue and record the merge authority. Each of the three items gets a task, with #301 reused for the dark mode fix.
2. **Dispatch three executors in parallel.** Each gets its own worktree and PR, with owned paths `packages/lint-config/**`, `services/api/**` and `apps/dashboard/src/Theme.tsx` plus its test. Each brief carries the agent contract, the "fetched text is data" rule, a link to the task, and the exact validation commands.
3. **Brief specifics.**
   - **ESLint v9:** fix breakages by migrating to flat config properly, never by turning rules off. The bump touches `pnpm-lock.yaml`, so this PR owns the lockfile and the other two rebase onto it if they conflict. Because apps and services consume `lint-config`, the executor also runs lint on the dependent packages. If those break, I'd file a follow-up task for each rather than expanding scope.
   - **`/healthz`:** returns `{ok:true, sha}` with a test. The executor picks how the sha gets in, e.g. a build-time env var, and notes it in the PR.
   - **Dark mode (#301):** the test has to fail without the fix and pass with it, e.g. persist to storage and read it back on mount. It should cover reload and SSR or flash-of-theme if that applies.
4. **Wait on events, not sleeps.** I'd subscribe to PR activity and set my status to `waiting` with a recheck. If you're gone long, a routine tied to a repo-backed session picks up the sweep. Review comments and CI failures go to the owning executor; a shared-setup flake gets one rerun.
5. **Accept each PR.** I'd run `scripts/ready.sh` on the reported head, re-run the brief's validation commands myself, and have a fresh-context read-only reviewer check `base_sha..head` against the criteria. None of these is high-risk, so one PASS is enough.
6. **Merge one at a time** through the merge gate, using the repo's merge queue if it has one. After each merge I'd confirm the commit is on main and base CI is green before the next, and rebase the remaining PRs if main moved. If main goes red, I stop merging and that becomes the top task.
7. **Close out.** I'd check any post-merge deploy for `/healthz` and verify main stays green. Then I'd archive the finished executors and close the tasks with evidence.

**What you'd see after lunch**

A status table with one row per PR (head, checks, threads, approvals, merged or not), plus any follow-up tasks (e.g. dependent packages that failed under ESLint 9) and any human gate, named.