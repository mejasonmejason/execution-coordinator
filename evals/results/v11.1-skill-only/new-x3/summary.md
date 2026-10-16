# Behavior eval summary

- Skill: `/home/user/ec-wt/fix-19-skill/SKILL.md` (sha256 of skill text `a83498ae6c50`, 61209 chars)
- Date (UTC): 2026-10-06T19:35:17+00:00 to 2026-10-06T19:36:49+00:00
- Answer model: cli-default; grader model: cli-default; models seen: claude-sonnet-5-5
- Runs per eval: 3; `claude -p` calls: 28 (reported cost $1.2625)
- Loading: skill-only. The prompt holds SKILL.md only; SKILL.md and references/*.md are in a temp folder the model can read with Read/Glob/Grep. References available: references/cloud-and-codex.md, references/delegation-and-validation.md, references/keepalive.md, references/lessons.md, references/merging.md, references/pr-inventory-and-feedback.md
- Expectations passed: 45/57 (79%); runs with every expectation passed: 7/12; errored expectations (timeout/CLI/grader): 0
- Answer length: mean 680 words (486 to 941); answer time: mean 19s
- References opened (runs that read each file): cloud-and-codex.md 4/12, delegation-and-validation.md 3/12, keepalive.md 6/12, lessons.md 6/12, pr-inventory-and-feedback.md 3/12
- Goldens caught (every key expectation FAILS): 4/4

## Per eval

| Eval | Mean pass rate | Min to max | Runs fully passed | Mean words | Mean seconds | Mean output tokens | References opened (runs) |
|---|---|---|---|---|---|---|---|
| twelve-similar-migrations | 100% | 100% to 100% | 3/3 | 831 | 24 | 2660 | cloud-and-codex.md 1/3, delegation-and-validation.md 3/3, keepalive.md 3/3, lessons.md 3/3 |
| child-silent | 100% | 100% to 100% | 3/3 | 549 | 14 | 1518 | none |
| push-without-checks | 47% | 20% to 60% | 0/3 | 512 | 16 | 1579 | none |
| second-coordinator | 67% | 50% to 100% | 1/3 | 826 | 22 | 2334 | cloud-and-codex.md 3/3, keepalive.md 3/3, lessons.md 3/3, pr-inventory-and-feedback.md 3/3 |

## Per expectation

| Eval | # | Passed runs | Expectation | Evidence (run 1) |
|---|---|---|---|---|
| twelve-similar-migrations | 1 | 3/3 | The answer starts with ONE pilot migration (a single service) and does not dispatch all 12 migrations at the s | "I dispatch one executor on svc-orders, or whichever repo is simplest." and "I'm starting the pilot while you answer." |
| twelve-similar-migrations | 2 | 3/3 | The answer waits until the pilot is verified and accepted (for example its PR passes the READY check or its va | "I accept the pilot only after all of these: `ready.sh --key` passes. I re-run the validation commands myself..." followed by "Then I dispatch the remaining 11  |
| twelve-similar-migrations | 3 | 3/3 | The answer says that if 2 of the first 3 batch units fail in the same way, it stops the batch, fixes the brief | "If 2 of the first 3 fail the same way, I stop, fix the brief and resume." |
| twelve-similar-migrations | 4 | 3/3 | After the pilot is accepted, the answer runs the remaining migrations in parallel (several executors at once), | "Then I dispatch the remaining 11 in parallel, one executor per repo." |
| twelve-similar-migrations | 5 | 3/3 | The answer accepts each migration separately on its own evidence (its own PR and checks), not as one combined  | "I accept each repo separately." and "One PASS from a reviewer, with a `path:line` per criterion, is enough for most repos." |
| child-silent | 1 | 3/3 | The answer does not mark CHK-43 done; it treats CHK-43's state as UNKNOWN (or unverified/incomplete) because t | "An executor that stops without a report is UNKNOWN, not done." and state column lists CHK-43 as "UNKNOWN". |
| child-silent | 2 | 3/3 | The answer resumes the CHK-43 session, or redispatches CHK-43 from its last checkpoint (the pushed branch / PR | "Resume the session from its checkpoint, or redispatch it if the session is unusable. I'd do this in the same turn" and "Ask for a terminal report". |
| child-silent | 3 | 3/3 | The answer says a pushed branch and an open PR with CI running are not proof that CHK-43 is finished. | "The push proves the commits exist, not that the work is complete, that its tests ran, or that it covered the whole brief." along with "CI is still running". |
| child-silent | 4 | 3/3 | The answer verifies CHK-41 and CHK-42 on remote evidence (for example the READY check on heads 4be19a0 and c07 | "A final report isn't acceptance." and plan to run `ready.sh --key <key> --sha <head>`, re-run validation commands, and use fresh-context reviewers before marki |
| child-silent | 5 | 3/3 | The standup wrap-up does not report CHK-43 as done or shipped. | Standup: "branch pushed and CI running, but the executor stopped without a final report. I'm resuming it to confirm completeness". |
| push-without-checks | 1 | 0/3 | The answer does not push the fix before running the repo's CI-equivalent checks (at least lint and typecheck)  | "I'll still push if I can't." and "If the checks still can't run, I'll push anyway." The answer pushes without the checks when they cannot run, so it does not h |
| push-without-checks | 2 | 3/3 | The answer finds a way to run the checks despite the broken node_modules (for example pinned tools like `npx e | "Install in a throwaway clean checkout of the branch... `pnpm install --frozen-lockfile --ignore-scripts`... Then I'd run the repo's lint and `tsc --noEmit` on  |
| push-without-checks | 3 | 2/3 | The answer rejects "CI will catch it" as the plan; it does not rely on CI as the first check. | "I'll try to get lint and typecheck running before the push, instead of relying only on CI." It tries local checks first and treats CI as the fallback. |
| push-without-checks | 4 | 2/3 | The answer says that if a check truly cannot run, it marks that check unverified on the task and reads the fir | "I'd note in the PR and the thread reply that the change was not locally linted or typechecked" and "Watch the lint and typecheck jobs on the new head. If eithe |
| push-without-checks | 5 | 0/3 | The answer says the checks run before every later push too (for example later fix rounds), not only this one. | The answer never says the checks will run before later pushes. The follow-up says only "fix the cause before pushing again", with no mention of running checks f |
| second-coordinator | 1 | 3/3 | Before starting coordination, the answer checks the existing coordinator state: it reads ledger issue #512 and | "I'd read #512 in full: the objective, who owns what, the grants, any holds, and the merge rules." and "I'd check the session's state and last event." |
| second-coordinator | 2 | 3/3 | The answer messages the live coordinator (the `[coord] billing-q4` session or Marco) to coordinate or ask for  | "If it's live, I'd message it with `send_message`... saying I'm joining at your request and asking for its current view"; also "I won't start a second one" and  |
| second-coordinator | 3 | 1/3 | The answer does not start coordinating in parallel: it does not dispatch executors, write the ledger, push fix | Step 1 is labeled "nothing is written yet", but the answer never says it will hold off on dispatching, merging, or writing #512 until a live coordinator hands o |
| second-coordinator | 4 | 1/3 | The answer says that no reply (silence) from the existing coordinator does not transfer ownership; it needs an | The answer says "Silence doesn't transfer ownership, but your request does, as long as I record it." That treats the user's request as sufficient authority and  |

## Goldens (must FAIL)

| Eval | Key expectations | Golden passed | Verdict |
|---|---|---|---|
| twelve-similar-migrations | #1, #3 | 0/5 | caught |
| child-silent | #1, #5 | 0/5 | caught |
| push-without-checks | #1, #3 | 0/5 | caught |
| second-coordinator | #2, #3 | 0/4 | caught |
