# Lessons learned

Read this on every nudge or resume, and before you change this skill, its scripts or its hooks. These are resume-time checks that the main rules do not already cover.

## Test every code-checkable lesson

Every lesson that code can check needs an offline, fixture-backed `gh` case in `tests/run.sh`. The suite must pass before and after every change to the skill, scripts or hooks, because a lesson without a test comes back.

## Resume-time checks

- Before the first push and every later push, run the repo's CI-equivalent checks on the changed files with pinned tools (`npx <tool>@<version from package.json>`, `gofmt -l`, `go vet`). A missing install is a problem to solve, not a reason to skip. If a check truly cannot run, mark it unverified on the task and read the first CI result at once, because "relying on CI" is not a plan.
- When CI is red, read the failing diagnostic before any rebase or rerun. If the log is truncated or buried in warnings, reproduce locally with error-level filtering and a higher diagnostic cap. Compare with the same job on base to tell a pre-existing failure from a caused one. Make at most one speculative push per failure.
- Before changing code for an error string, search for it across the org's repos to find the owning repo. A client workaround for a backend limit needs the owner's decision on the task.
- Schedule your own next check. Never rely only on the sweeper, because it may be paused, offset or down. Offset your trigger from the sweeper schedule (see the event loop and sweep in SKILL.md).
- When the audit exits 3, report the PR as unreadable. Read the comments through REST: `gh api --paginate repos/O/R/pulls/N/comments`, `.../issues/N/comments` and `.../pulls/N/reviews`. Thread resolution then stays unverified. Retry GraphQL after its reset (`gh api rate_limit`). When two audits conflict, prefer the one with more owed items.
- Notify owners of owed replies whatever their status says. Standing authority is described under operating authority in SKILL.md, and held replies under the `human-gate` rule.
- Filter or transform large tool output. Never ask for a word-for-word copy, because it wastes context and copies errors.
- Change one automation setting at a time. Verify two runs before calling it done, because a single run can pass by chance.
- For paginated JSON, use `gh api --paginate --jq` and print one element per line, because `--paginate` alone concatenates JSON documents that most parsers reject.
- Before a watcher resends or follows up, verify how the first message was received.
- Never message finished executors; archive them instead. A message wakes an idle session and resets its idle timer. One broadcast kept eleven finished executors alive.
- Claude Code cloud sessions refuse GraphQL and non-repo API paths. Before the REST fallback existed, `ready.sh` blocked every merge there. Use the cloud REST forms.
