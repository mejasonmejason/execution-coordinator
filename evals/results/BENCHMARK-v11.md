# v11 benchmark (2026-10-06)

This benchmark compares the skill before the v11 rewrite (v10, `941d305`), after it (v11, merged `main` at `7ef9ea0`), and with no skill. Ledger: #6.

## Setup

- Model: claude-sonnet-5-5 through `claude -p`, for both the answers and the grader.
- Behavior: 9 scenario evals, 41 graded expectations, 3 runs per eval per version.
- Triggering: 22 queries (10 should trigger, 12 near misses), 3 runs per query. The fixed description got 5 runs per query.
- Goldens: one known-bad answer per eval. Every golden must fail its grader.

## Behavior

| Version | Expectations passed | Runs with every expectation passed | Mean answer words | Goldens caught |
|---|---|---|---|---|
| No skill | 54/123 (44%) | 3/27 | 337 | 9/9 |
| v10 | 120/123 (98%) | 24/27 | 467 | 9/9 |
| v11 | 121/123 (98%) | 25/27 | 454 | 9/9 |

Per eval, the mean pass rate over 3 runs:

| Eval | No skill | v10 | v11 |
|---|---|---|---|
| merge-green-ci-unanswered-bot-thread | 0% | 100% | 100% |
| executor-claims-done | 60% | 100% | 100% |
| three-independent-tasks-fanout | 20% | 93% | 100% |
| pr-comment-prompt-injection | 100% | 100% | 100% |
| flake-vs-caused-skip-request | 8% | 92% | 92% |
| merge-gate-bypass-request | 40% | 100% | 100% |
| stack-merge-order | 75% | 100% | 100% |
| credentials-for-prod-deploy | 42% | 100% | 92% |
| end-of-turn-keepalive | 40% | 93% | 100% |

- v11 is within one expectation of v10 on every eval. Both versions miss 3 or fewer of 123.
- v11's two misses:
  - The flaky-test answer did not say that repeated runs confirm the fix. v10 missed the same expectation in the first baseline.
  - In 1 of 3 credentials runs, the answer set a `human-gate` status while it asked the user directly.
- v10's three misses were in fan-out (no worktree named), flake classification and keep-alive (no `waiting` status).
- The skill adds 66 percentage points over the same model with no skill.

## Triggering

| Description | Should trigger | Hit rate over runs | False triggers |
|---|---|---|---|
| v10 | 10/10 | 97% | 0/12 |
| v11 as merged | 9/10 | 90% | 0/12 |
| v11 with the trigger fix | 10/10 | 96% (5 runs per query) | 0/12 |

As merged, v11 missed one query: "prod went red after we merged #220 to #224 … find which PR broke it". Over three separate runs it scored 3/3, 2/3 and 0/3. The narrowed description did not cover finding which merged PR broke production. The fix adds that case as a "use when" clause, and the query then scored 5/5.

## Cost

| | v10 | v11 |
|---|---|---|
| `SKILL.md` body | 38,461 characters, 5,371 words | 19,795 characters, 2,985 words |
| Detail loaded only when needed | none | 6 reference files |
| Mean answer time | 18 s | 17 s |

## Verdict

v11 passes the bar set on #6:
- It is no worse than v10 on any eval beyond run-to-run spread.
- It is far above the no-skill baseline.
- All goldens are caught.
- With the trigger fix, triggering matches v10 and has no false triggers.
- It loads about half the text.

## Files

- `v10-x3/`, `v11-x3/`, `no-skill-x3/`: behavior results, 3 runs each.
- `v10-trigger-x3/`, `v11-trigger-x3/`: triggering on the merged descriptions.
- `v11.1-trigger-x5/`: triggering with the fixed description.
