# Trigger eval summary

- Skill: `/tmp/claude-0/v10skill/SKILL.md` (sha256 `d5072fb5b9c4`)
- Description: Coordinate engineering from plan through merge, deployment and verification using parallel agents, sessions, PR stacks, CI, reviews, public tools and bundled scripts, in Claude Code (including cloud sessions) or Codex. Use for execution, agent coordination, PR/stack completion, task tracking or sustained progress.
- Date (UTC): 2026-10-06T18:01:26Z; wall time 46s; model: claude-sonnet-5-5; runs per query: 3; `claude -p` calls: 66
- Should trigger: 10/10 queries pass; hit rate over runs 97%
- Should not trigger: 12/12 queries pass; false-trigger rate over runs 0%
- Precision 1.00, recall 1.00 (query level, threshold 0.5); inconclusive (timeout) queries: 0

| Expected | Triggers / runs | Result | Query |
|---|---|---|---|
| trigger | 3/3 | PASS | I've got 6 open PRs across acme/api and acme/web for the billing migration (#311 through #316). #313-#315 are stacked, t |
| trigger | 3/3 | PASS | spin up parallel agents for issues #88, #91, #95 and #102 in our pnpm monorepo, each in its own worktree and branch, and |
| trigger | 3/3 | PASS | Coordinate the rollout of the new auth service. The plan is in docs/auth-plan.md: 5 phases, one PR each, phase 3 depends |
| trigger | 3/3 | PASS | my stack for the search rewrite (#101 <- #102 <- #103 <- #104) has to land today. restack after each merge, babysit CI o |
| trigger | 3/3 | PASS | I'm offline from friday night till monday. set things up so the open PRs under the payments-v2 epic keep getting swept:  |
| trigger | 2/3 | PASS | there are three claude code cloud sessions working on the data pipeline refactor and I lost track of who is doing what.  |
| trigger | 3/3 | PASS | We need to move 40 Go services from logrus to slog. Do one service as a pilot, then fan the rest out in batches across a |
| trigger | 3/3 | PASS | codex is working on #450 and #451 and a claude session has #452. be the control tower: watch reviews and CI on all three |
| trigger | 3/3 | PASS | take the Q4 tech-debt list in issue #700 (12 checkbox items), turn each into a task, run the independent ones in paralle |
| trigger | 3/3 | PASS | prod went red after we merged #220 to #224 this morning. find which PR broke it, get a fix PR up (or coordinate a revert |
| no trigger | 0/3 | PASS | fix the off-by-one in src/utils/paginate.ts (page 2 repeats the last item of page 1) and open a PR for it |
| no trigger | 0/3 | PASS | can you explain what scripts/ready.sh does in this repo? especially how the --paths glob matching works, I don't get the |
| no trigger | 0/3 | PASS | write one unit test for parse_invoice_date in billing/dates.py that covers the DST spring-forward edge case (2026-03-08  |
| no trigger | 0/3 | PASS | review PR #318 for style only: naming, comments, formatting. don't push anything, just leave review comments |
| no trigger | 0/3 | PASS | set up GitHub Actions CI from scratch for this python repo: ruff, mypy and pytest on 3.11 and 3.12, cache pip, fail on c |
| no trigger | 0/3 | PASS | what's the actual difference between a GitHub merge queue and auto-merge? which one should a 5-person team with one requ |
| no trigger | 0/3 | PASS | my PR #77 has a merge conflict in package-lock.json after main moved. what's the cleanest way to resolve it? |
| no trigger | 0/3 | PASS | summarize the review comments on PR #412 in 3 bullets, I just want to know what people are complaining about |
| no trigger | 0/3 | PASS | write me a git alias that rebases my current branch onto origin/main and then force-pushes with lease |
| no trigger | 0/3 | PASS | add a CODEOWNERS file so anything under services/payments/ needs review from @acme/payments-team and docs/ needs @acme/d |
| no trigger | 0/3 | PASS | can you keep a running todo list of what's left on my thesis code refactor (just me, one repo, no PRs yet) and tick thin |
| no trigger | 0/3 | PASS | keep going on the flaky websocket reconnect bug in client/ws.ts until client/ws.test.ts passes 20 times in a row. don't  |
