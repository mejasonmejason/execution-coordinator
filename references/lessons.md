# Lessons learned

Read this on every nudge or resume, and before you change this skill, its scripts or its hooks. These are resume-time checks that the main rules do not already cover.

## Test every code-checkable lesson

Every lesson that code can check needs an offline, fixture-backed `gh` case in `tests/run.sh`. Run the suite before and after every change to the skill, scripts or hooks, because a lesson without a test comes back.

## Resume-time checks

- Schedule your own next check. Never rely only on the sweeper, because it may be paused, offset or down. Offset your trigger from the sweeper schedule (see the event loop and sweep in SKILL.md).
- When the audit exits 3, report the PR as unreadable. Read the comments through REST: `gh api --paginate repos/O/R/pulls/N/comments`, `.../issues/N/comments` and `.../pulls/N/reviews`. Thread resolution then stays unverified. Retry GraphQL after its reset (`gh api rate_limit`). When two audits conflict, prefer the one with more owed items.
- Notify owners of owed replies whatever their status says. Standing authority is described under operating authority in SKILL.md, and held replies under the `human-gate` rule.
- Filter or transform large tool output. Never ask for a word-for-word copy, because it wastes context and copies errors.
- Change one automation setting at a time. Verify two runs before calling it done, because a single run can pass by chance.
- For paginated JSON, use `gh api --paginate --jq` and print one element per line, because `--paginate` alone concatenates JSON documents that most parsers reject.
- Before a watcher resends or follows up, verify how the first message was received.
- Never message finished executors; archive them instead. A message wakes an idle session and resets its idle timer. One broadcast kept eleven finished executors alive.
- Claude Code cloud sessions refuse GraphQL and non-repo API paths. Before the REST fallback existed, `ready.sh` blocked every merge there. Use the cloud REST forms.
