# Lessons learned

You must read this at the kickoff of any coordination, on every nudge or resume, and before you change this skill, its scripts or its hooks. Where SKILL.md already states a rule, the line here gives only the detail and the incident behind it.

## Test every code-checkable lesson

Every lesson that code can check needs an offline, fixture-backed `gh` case in `tests/run.sh`. The suite must pass before and after every change to the skill, scripts or hooks, because a lesson without a test comes back.

## Resume-time checks

- Per-push checks (rule in the SKILL.md guardrails): pin the tools, for example `npx <tool>@<version from package.json>`, `gofmt -l`, `go vet`. A missing install is a problem to solve, not a reason to skip. If a check truly cannot run, mark it unverified on the task and read the first CI result at once.
- Failing diagnostics (rule in the SKILL.md guardrails): if the log is truncated or buried in warnings, reproduce locally with error-level filtering and a higher diagnostic cap. Compare with the same job on base to tell a pre-existing failure from a caused one. Make at most one speculative push per failure.
- Before changing code for an error string, search for it across the org's repos to find the owning repo. A client workaround for a backend limit needs the owner's decision on the task.
- Your own next check (rule in the SKILL.md event loop): never rely only on the sweeper, and offset your trigger from the sweeper schedule.
- When the audit exits 3, report the PR as unreadable. Read the comments through REST: `gh api --paginate repos/O/R/pulls/N/comments`, `.../issues/N/comments` and `.../pulls/N/reviews`. Thread resolution then stays unverified. Retry GraphQL after its reset (`gh api rate_limit`). When two audits conflict, prefer the one with more owed items.
- Owed replies (rule in the SKILL.md event loop): standing authority is under operating authority in SKILL.md, and held replies under the `human-gate` rule in the keep-alive reference.
- Filter or transform large tool output. Never ask for a word-for-word copy, because it wastes context and copies errors.
- Change one automation setting at a time. Verify two runs before calling it done, because a single run can pass by chance.
- For paginated JSON, use `gh api --paginate --jq` and print one element per line, because `--paginate` alone concatenates JSON documents that most parsers reject.
- Before a watcher resends or follows up, verify how the first message was received.
- Finished executors (rule in the SKILL.md event loop): a message resets an idle session's timer. One broadcast kept eleven finished executors alive.
- Claude Code cloud sessions refuse GraphQL and non-repo API paths. Before the REST fallback existed, `ready.sh` blocked every merge there. Use the cloud REST forms.
- Read the exit code of `ready.sh` itself. Never pipe it into another command before a merge: in `ready.sh … | grep … && merge`, the `&&` tests grep, not READY. That shape merged a NOT READY PR (#41).
- When a review bot is out of quota, its status summary stays on an older commit, so READY blocks. Replace that review with a fresh-context review, then merge with a logged `COORD_READY_OVERRIDE` that names the review. Never get past READY any other way.
