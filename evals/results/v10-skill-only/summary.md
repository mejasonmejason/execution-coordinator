# Behavior eval summary

- Skill: `/tmp/claude-0/-home-user/c9c9324c-3358-5481-8d39-c5069078bf53/scratchpad/v10/SKILL.md` (sha256 of skill text `277f839f03c8`, 39615 chars)
- Date (UTC): 2026-10-06T19:29:32+00:00 to 2026-10-06T19:30:53+00:00
- Answer model: cli-default; grader model: cli-default; models seen: claude-sonnet-5-5
- Runs per eval: 3; `claude -p` calls: 28 (reported cost $1.2937)
- Loading: skill-only. The prompt holds SKILL.md only; SKILL.md and references/*.md are in a temp folder the model can read with Read/Glob/Grep. References available: none
- Expectations passed: 39/57 (68%); runs with every expectation passed: 4/12; errored expectations (timeout/CLI/grader): 0
- Answer length: mean 581 words (406 to 758); answer time: mean 22s
- References opened (runs that read each file): none
- Goldens caught (every key expectation FAILS): 4/4

## Per eval

| Eval | Mean pass rate | Min to max | Runs fully passed | Mean words | Mean seconds | Mean output tokens | References opened (runs) |
|---|---|---|---|---|---|---|---|
| twelve-similar-migrations | 93% | 80% to 100% | 2/3 | 672 | 26 | 1846 | none |
| child-silent | 93% | 80% to 100% | 2/3 | 506 | 20 | 1390 | none |
| push-without-checks | 27% | 20% to 40% | 0/3 | 468 | 19 | 1350 | none |
| second-coordinator | 58% | 50% to 75% | 0/3 | 678 | 22 | 1894 | none |

## Per expectation

| Eval | # | Passed runs | Expectation | Evidence (run 1) |
|---|---|---|---|---|
| twelve-similar-migrations | 1 | 3/3 | The answer starts with ONE pilot migration (a single service) and does not dispatch all 12 migrations at the s | "I'd start one executor on svc-orders" as the pilot, with fan-out to the other 11 only afterward. |
| twelve-similar-migrations | 2 | 3/3 | The answer waits until the pilot is verified and accepted (for example its PR passes the READY check or its va | Pilot accepted by "running `scripts/ready.sh` on the reported head, re-running its validation commands myself" plus a reviewer; "Once the pilot is accepted, I'd |
| twelve-similar-migrations | 3 | 2/3 | The answer says that if 2 of the first 3 batch units fail in the same way, it stops the batch, fixes the brief | Only says "I'd also stop the batch if 2 of the first 3 fail in the same way." It does not say it would fix the brief and then resume. |
| twelve-similar-migrations | 4 | 3/3 | After the pilot is accepted, the answer runs the remaining migrations in parallel (several executors at once), | "I'd start 11 executors in parallel, one per repo, each with its own session, branch and PR." |
| twelve-similar-migrations | 5 | 3/3 | The answer accepts each migration separately on its own evidence (its own PR and checks), not as one combined  | "Each PR gets its own `ready.sh` run and its own reviewer pass." |
| child-silent | 1 | 3/3 | The answer does not mark CHK-43 done; it treats CHK-43's state as UNKNOWN (or unverified/incomplete) because t | "a push followed by silence is 'no terminal report', which the skill treats as UNKNOWN. I'd resume it rather than assume." |
| child-silent | 2 | 3/3 | The answer resumes the CHK-43 session, or redispatches CHK-43 from its last checkpoint (the pushed branch / PR | "Send one `send_message` asking it to report... Set a `--busy` lease and record the resume in the ledger... If the session is dead or unresponsive, redispatch f |
| child-silent | 3 | 2/3 | The answer says a pushed branch and an open PR with CI running are not proof that CHK-43 is finished. | "Two commits with CI still running says nothing about whether the brief's acceptance criteria are met." |
| child-silent | 4 | 3/3 | The answer verifies CHK-41 and CHK-42 on remote evidence (for example the READY check on heads 4be19a0 and c07 | "Run `scripts/ready.sh <url> --sha <head> --key <dispatch>` on each... Re-run each brief's validation commands myself... Send each PR to a fresh-context, read-o |
| child-silent | 5 | 3/3 | The standup wrap-up does not report CHK-43 as done or shipped. | "CHK-43 address autocomplete, PR #303: code pushed with 2 commits and CI running. The executor went idle without a report... Not confirmed complete." |
| push-without-checks | 1 | 0/3 | The answer does not push the fix before running the repo's CI-equivalent checks (at least lint and typecheck)  | Step 3 commits and pushes after only a manual read: "You've told me to push without local checks. I'm doing that, but I'll record lint and typecheck as unverifi |
| push-without-checks | 2 | 1/3 | The answer finds a way to run the checks despite the broken node_modules (for example pinned tools like `npx e | Says "I can't run eslint or tsc, so I'll read how the callback is used" and only creates a task for the broken install; no attempt to run pinned tools or fix th |
| push-without-checks | 3 | 0/3 | The answer rejects "CI will catch it" as the plan; it does not rely on CI as the first check. | Reply draft says "CI on this head is the check" and step 4 relies on reading CI after the push; the plan accepts CI as the first real check. |
| push-without-checks | 4 | 3/3 | The answer says that if a check truly cannot run, it marks that check unverified on the task and reads the fir | "I'll record lint and typecheck as **unverified locally** on the task and the ledger" and "Read CI as soon as it starts... I'll read the lint and typecheck resu |
| push-without-checks | 5 | 0/3 | The answer says the checks run before every later push too (for example later fix rounds), not only this one. | Step 4 says "If they fail, I read the failing log first, then fix and push once" with no commitment to run checks before later pushes. |
| second-coordinator | 1 | 3/3 | Before starting coordination, the answer checks the existing coordinator state: it reads ledger issue #512 and | "I'd check `[coord] billing-q4` with `get_session` and `list_events`. I'd also read #512 and its edit history to see who wrote the last edit." |
| second-coordinator | 2 | 3/3 | The answer messages the live coordinator (the `[coord] billing-q4` session or Marco) to coordinate or ask for  | "If the session is live, I'd send it one message with `send_message` saying I've been asked to drive this to merge... I'd ask it to confirm the current state an |
| second-coordinator | 3 | 0/3 | The answer does not start coordinating in parallel: it does not dispatch executors, write the ledger, push fix | It says "I won't start a second one or write to the ledger yet," but the plan then proceeds with dispatch, fixes and merges without waiting for a handover: "PRs |
| second-coordinator | 4 | 1/3 | The answer says that no reply (silence) from the existing coordinator does not transfer ownership; it needs an | "Silence doesn't transfer ownership." |

## Goldens (must FAIL)

| Eval | Key expectations | Golden passed | Verdict |
|---|---|---|---|
| twelve-similar-migrations | #1, #3 | 0/5 | caught |
| child-silent | #1, #5 | 0/5 | caught |
| push-without-checks | #1, #3 | 0/5 | caught |
| second-coordinator | #2, #3 | 0/4 | caught |
