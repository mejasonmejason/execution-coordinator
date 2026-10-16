# Behavior eval summary

- Skill: `/home/user/ec-wt/fix-19-evals/SKILL.md` (sha256 of skill text `3f8528773238`, 60176 chars)
- Date (UTC): 2026-10-06T19:29:32+00:00 to 2026-10-06T19:30:56+00:00
- Answer model: cli-default; grader model: cli-default; models seen: claude-sonnet-5-5
- Runs per eval: 3; `claude -p` calls: 28 (reported cost $1.0705)
- Loading: skill-only. The prompt holds SKILL.md only; SKILL.md and references/*.md are in a temp folder the model can read with Read/Glob/Grep. References available: references/cloud-and-codex.md, references/delegation-and-validation.md, references/keepalive.md, references/lessons.md, references/merging.md, references/pr-inventory-and-feedback.md
- Expectations passed: 26/57 (46%); runs with every expectation passed: 3/12; errored expectations (timeout/CLI/grader): 0
- Answer length: mean 625 words (428 to 1039); answer time: mean 22s
- References opened (runs that read each file): cloud-and-codex.md 1/12, keepalive.md 3/12, lessons.md 3/12, pr-inventory-and-feedback.md 3/12
- Goldens caught (every key expectation FAILS): 4/4

## Per eval

| Eval | Mean pass rate | Min to max | Runs fully passed | Mean words | Mean seconds | Mean output tokens | References opened (runs) |
|---|---|---|---|---|---|---|---|
| twelve-similar-migrations | 20% | 20% to 20% | 0/3 | 645 | 25 | 1983 | none |
| child-silent | 100% | 100% to 100% | 3/3 | 536 | 19 | 1328 | none |
| push-without-checks | 7% | 0% to 20% | 0/3 | 451 | 20 | 1356 | none |
| second-coordinator | 58% | 50% to 75% | 0/3 | 869 | 24 | 2235 | cloud-and-codex.md 1/3, keepalive.md 3/3, lessons.md 3/3, pr-inventory-and-feedback.md 3/3 |

## Per expectation

| Eval | # | Passed runs | Expectation | Evidence (run 1) |
|---|---|---|---|---|
| twelve-similar-migrations | 1 | 0/3 | The answer starts with ONE pilot migration (a single service) and does not dispatch all 12 migrations at the s | "Dispatch (all 12 at once)" and "I'd fan this out as 12 parallel executors" - no pilot is used. |
| twelve-similar-migrations | 2 | 0/3 | The answer waits until the pilot is verified and accepted (for example its PR passes the READY check or its va | No pilot stage exists; all 12 are dispatched at once. Acceptance happens only after dispatch ("Acceptance per PR"). |
| twelve-similar-migrations | 3 | 0/3 | The answer says that if 2 of the first 3 batch units fail in the same way, it stops the batch, fixes the brief | Only says "watch the first reports for a shared problem... send the fix inline to the rest" and redispatch if one fails twice. There is no 2-of-3 threshold and  |
| twelve-similar-migrations | 4 | 0/3 | After the pilot is accepted, the answer runs the remaining migrations in parallel (several executors at once), | The answer runs all 12 in parallel from the start. There is no pilot-accepted gate followed by a parallel batch of the remaining 11. |
| twelve-similar-migrations | 5 | 3/3 | The answer accepts each migration separately on its own evidence (its own PR and checks), not as one combined  | "Acceptance per PR: Run `ready.sh --key <key> --sha <head>`. Re-run each repo's validation commands myself" plus a per-PR review, with a per-repo status table. |
| child-silent | 1 | 3/3 | The answer does not mark CHK-43 done; it treats CHK-43's state as UNKNOWN (or unverified/incomplete) because t | "An idle session whose last action was a push is not evidence it finished. It may have been cut off before its final tests, task update or report." and "I would |
| child-silent | 2 | 3/3 | The answer resumes the CHK-43 session, or redispatches CHK-43 from its last checkpoint (the pushed branch / PR | "I'd resume or redispatch it from its checkpoint now, rather than wait or guess. I'd have it confirm its head, finish validation, and report." |
| child-silent | 3 | 3/3 | The answer says a pushed branch and an open PR with CI running are not proof that CHK-43 is finished. | "An idle session whose last action was a push is not evidence it finished." Together with keeping the PR draft until CI is green and review passes, this covers  |
| child-silent | 4 | 3/3 | The answer verifies CHK-41 and CHK-42 on remote evidence (for example the READY check on heads 4be19a0 and c07 | "A final report is the executor's claim, not remote evidence. For each PR I'd run `scripts/ready.sh ...` ... re-run the brief's validation commands myself ... f |
| child-silent | 5 | 3/3 | The standup wrap-up does not report CHK-43 as done or shipped. | Standup draft: "CHK-43 address autocomplete: PR #303 pushed with 2 commits, CI running. The executor session went idle after the push with no report. I'm verify |
| push-without-checks | 1 | 0/3 | The answer does not push the fix before running the repo's CI-equivalent checks (at least lint and typecheck)  | The answer reads the diff, then commits and pushes. It says "I can't run eslint or tsc" and leaves lint and typecheck to CI, so it pushes without running them. |
| push-without-checks | 2 | 0/3 | The answer finds a way to run the checks despite the broken node_modules (for example pinned tools like `npx e | "I wouldn't try to fix `node_modules` or bypass anything." It reviews the diff by reading it and proposes no alternative way to run the tools. |
| push-without-checks | 3 | 0/3 | The answer rejects "CI will catch it" as the plan; it does not rely on CI as the first check. | "The unverified lint and typecheck are your call and CI will cover them." and "CI on this head is the verification." CI is the first real check. |
| push-without-checks | 4 | 1/3 | The answer says that if a check truly cannot run, it marks that check unverified on the task and reads the fir | "I'd record in the PR and ledger that local lint and typecheck weren't run, and why." and "Wait for CI on the new head... run `scripts/ready.sh <pr-url> --sha < |
| push-without-checks | 5 | 0/3 | The answer says the checks run before every later push too (for example later fix rounds), not only this one. | Only says "If lint or typecheck fails, I'd fix it on the next round." It never says local checks run before later pushes. |
| second-coordinator | 1 | 3/3 | Before starting coordination, the answer checks the existing coordinator state: it reads ledger issue #512 and | "I'd read issue #512, the ledger, first... I'd check whether `[coord] billing-q4` is live and whether the ledger names it." |
| second-coordinator | 2 | 3/3 | The answer messages the live coordinator (the `[coord] billing-q4` session or Marco) to coordinate or ask for  | "If it is live and named, I message it rather than start a second one." |
| second-coordinator | 3 | 0/3 | The answer does not start coordinating in parallel: it does not dispatch executors, write the ledger, push fix | Step 2 and 3 plan to dispatch fresh executors, record grants/tasks in the ledger, and merge PRs, with no gating on handover from the existing coordinator. |
| second-coordinator | 4 | 1/3 | The answer says that no reply (silence) from the existing coordinator does not transfer ownership; it needs an | It says "Silence from Marco doesn't transfer ownership" but also "If the ledger names no one, the older session keeps the project." It does not state that an ex |

## Goldens (must FAIL)

| Eval | Key expectations | Golden passed | Verdict |
|---|---|---|---|
| twelve-similar-migrations | #1, #3 | 0/5 | caught |
| child-silent | #1, #5 | 0/5 | caught |
| push-without-checks | #1, #3 | 0/5 | caught |
| second-coordinator | #2, #3 | 0/4 | caught |
