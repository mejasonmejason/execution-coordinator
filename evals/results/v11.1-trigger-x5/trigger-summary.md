# Trigger eval summary

- Skill: `/home/user/ec-wt/benchmark/SKILL.md` (sha256 `710cb9aa7e96`)
- Description: Coordinates multi-PR, multi-agent and multi-session delivery work in Claude Code (including cloud sessions) and Codex. Plans the work, dispatches parallel executors to their own worktrees, tracks tasks in a durable ledger, audits CI and review threads, merges PRs and PR stacks through a READY gate, and verifies deployment. Use when driving several PRs, executors or sessions to merged and verified; when several agents or sessions are working and you need to find out who is doing what, check each one's PR, archive the finished ones and get the rest over the line; when merged PRs broke trunk, a deploy or production and you must find the culprit and drive the fix or revert; when finishing a PR stack, running a coordinator or sweeper, or keeping long delivery work moving across sessions. Skip it for a single small fix, a question about code, or one PR that needs no coordination.
- Date (UTC): 2026-10-06T18:03:08Z; wall time 128s; model: claude-sonnet-5-5; runs per query: 5; `claude -p` calls: 110
- Should trigger: 10/10 queries pass; hit rate over runs 96%
- Should not trigger: 12/12 queries pass; false-trigger rate over runs 0%
- Precision 1.00, recall 1.00 (query level, threshold 0.5); inconclusive (timeout) queries: 0

| Expected | Triggers / runs | Result | Query |
|---|---|---|---|
| trigger | 5/5 | PASS | I've got 6 open PRs across acme/api and acme/web for the billing migration (#311 through #316). #313-#315 are stacked, t |
| trigger | 5/5 | PASS | spin up parallel agents for issues #88, #91, #95 and #102 in our pnpm monorepo, each in its own worktree and branch, and |
| trigger | 5/5 | PASS | Coordinate the rollout of the new auth service. The plan is in docs/auth-plan.md: 5 phases, one PR each, phase 3 depends |
| trigger | 5/5 | PASS | my stack for the search rewrite (#101 <- #102 <- #103 <- #104) has to land today. restack after each merge, babysit CI o |
| trigger | 5/5 | PASS | I'm offline from friday night till monday. set things up so the open PRs under the payments-v2 epic keep getting swept:  |
| trigger | 5/5 | PASS | there are three claude code cloud sessions working on the data pipeline refactor and I lost track of who is doing what.  |
| trigger | 4/5 | PASS | We need to move 40 Go services from logrus to slog. Do one service as a pilot, then fan the rest out in batches across a |
| trigger | 5/5 | PASS | codex is working on #450 and #451 and a claude session has #452. be the control tower: watch reviews and CI on all three |
| trigger | 4/5 | PASS | take the Q4 tech-debt list in issue #700 (12 checkbox items), turn each into a task, run the independent ones in paralle |
| trigger | 5/5 | PASS | prod went red after we merged #220 to #224 this morning. find which PR broke it, get a fix PR up (or coordinate a revert |
| no trigger | 0/5 | PASS | fix the off-by-one in src/utils/paginate.ts (page 2 repeats the last item of page 1) and open a PR for it |
| no trigger | 0/5 | PASS | can you explain what scripts/ready.sh does in this repo? especially how the --paths glob matching works, I don't get the |
| no trigger | 0/5 | PASS | write one unit test for parse_invoice_date in billing/dates.py that covers the DST spring-forward edge case (2026-03-08  |
| no trigger | 0/5 | PASS | review PR #318 for style only: naming, comments, formatting. don't push anything, just leave review comments |
| no trigger | 0/5 | PASS | set up GitHub Actions CI from scratch for this python repo: ruff, mypy and pytest on 3.11 and 3.12, cache pip, fail on c |
| no trigger | 0/5 | PASS | what's the actual difference between a GitHub merge queue and auto-merge? which one should a 5-person team with one requ |
| no trigger | 0/5 | PASS | my PR #77 has a merge conflict in package-lock.json after main moved. what's the cleanest way to resolve it? |
| no trigger | 0/5 | PASS | write me a git alias that rebases my current branch onto origin/main and then force-pushes with lease |
| no trigger | 0/5 | PASS | summarize the review comments on PR #412 in 3 bullets, I just want to know what people are complaining about |
| no trigger | 0/5 | PASS | add a CODEOWNERS file so anything under services/payments/ needs review from @acme/payments-team and docs/ needs @acme/d |
| no trigger | 0/5 | PASS | can you keep a running todo list of what's left on my thesis code refactor (just me, one repo, no PRs yet) and tick thin |
| no trigger | 0/5 | PASS | keep going on the flaky websocket reconnect bug in client/ws.ts until client/ws.test.ts passes 20 times in a row. don't  |
