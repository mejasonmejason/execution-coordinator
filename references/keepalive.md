# Keep-alive, status and reports

Read this when you need the operating-layer detail, set or read a session's status, write a `human-gate` or a decision issue, install the Stop or merge-gate hook, name sessions, find a second coordinator, write a status report, turn keep-alive off, or offboard a finished project.

## Contents

- Operating layers
- Status commands
- Rules for every agent
- Decision issues
- One coordinator per project
- Enforcers
- Install the hooks
- Quiet hours
- Session names
- Off switches
- Status report template
- Offboarding

## Operating layers

| Layer | Mechanism | Latency | Runs when |
|---|---|---|---|
| L0 Repository reflex | Branch protection, required checks, merge queue or auto-merge, CODEOWNERS, optional hosted agent triggered by `@mention` | seconds | always |
| L1 Control tower | This coordinator session in any agent CLI, reacting to events | under a minute | while the session is live |
| L2 Sweeper | Scheduled headless agent run (cron, launchd, systemd timer, or a GitHub Actions `schedule`) that reconciles the ledger | 10 to 60 min | when the tower is offline or stuck |
| L3 Event trigger | GitHub Actions on `pull_request_review`, `pull_request_review_comment`, `issue_comment`, `check_suite` that runs a hosted agent or pings the owner | seconds | when configured |

## Status commands

Each session owns `<repo or worktree>/.coordinator/status.json`. `scripts/status.sh` keeps that file git-ignored.

```bash
S=<path to this skill>/scripts/status.sh
$S set active "<next concrete action>"            # work you can do now
$S set waiting "<what you await>" --recheck 10    # only CI, review, or background runs remain
$S set waiting "<fan-out>" --busy 90               # lease: hooks stand down for 90 min; --busy 0 clears
$S set human-gate "<person>: <exact decision>"     # sole blocker is a person
$S set done "<fence met evidence>"
$S get
```

In a Claude Code cloud session, also mirror the status to the ledger and use the cloud session tools for later events, because the container and its status file end with the session. Install the hooks in the repo's `.claude/settings.json` there, because a cloud session loads only the settings in its checkout.

## Rules for every agent

1. Set status at the start and before ending every turn.
2. Never end a turn `active` without doing work. Never use `waiting` or `human-gate` to avoid work you can do, because the hook and the sweeper trust the status.
3. On a nudge or resume, re-read the status, the ledger, your task and the lessons reference. Act, then update status. Resume or redispatch stopped children in the same turn, as the first guardrail in SKILL.md says.
4. Make real progress between nudges, not timestamp-only rewrites. After the hook releases a stalled session, the sweeper takes over.
5. A `human-gate` status names the person and the exact human-only decision (see operating authority in SKILL.md). Use this format: `[since MM-DD] Person: decision; ...; Meanwhile: <machine work>`. Keep the original dates.
   - Every day, re-verify each item against live state.
   - Remove answered or obsolete items (give the reason), items you can do yourself, and items that belong to other people (chase those people instead).
   - Include every open user question.
   - A held reply needs a draft or a thread link.
6. One owner per status file, and one executor per worktree. Only the owner of a member repo writes that repo's status. `scripts/status.sh` refuses non-git directories and `$HOME`.
7. Before a scheduled gap or quiet hours, set `waiting` with a precise next action.

Observation-only sessions have no keep-alive.

## Decision issues

A human decision is a real choice between options only. Credentials, review waits and one-answer fixes are not decisions.

1. Open one GitHub issue per decision, labelled `decision`, with the options, your recommendation and the cost if wrong.
2. Link it from the ledger and from the `human-gate` status.
3. Close it with the named person's answer.

## One coordinator per project

Find and message the live coordinator instead of starting another coordinator or sweeper, because two coordinators make conflicting writes.

- If you find two, both stop writing. The one the ledger names keeps the project; if the ledger names neither, the older one keeps it. The other hands over.
- Silence never transfers ownership.
- Retire executors as their tasks finish (MERGE step 5 in SKILL.md).
- Each sweep archives idle sessions whose tasks are all `accepted` or `abandoned`.

## Enforcers

| Enforcer | Behavior |
|---|---|
| Claude Code or Codex Stop hook (`hooks/claude-stop-hook.sh`) | While the status is `active`, it blocks the stop and feeds back the next action. It releases the session after 8 blocks with no change to state, next action, HEAD or worktree. `status.sh set` resets the count. It skips a different owner only when both `owner_session` and the hook's `session_id` exist, so set `$CLAUDE_CODE_SESSION_ID` (Codex: `$CODEX_THREAD_ID`); the nearest agent process wins. A live busy lease makes it stand down. |
| L2 sweeper | Nudges idle `active` sessions, and `waiting` sessions whose recheck is due, through their terminal or a headless resume. |
| Other harnesses | Use the harness's own continuation hook if it has one. Otherwise rely on the sweeper. |

## Install the hooks

Put this in `.claude/settings.json` (project) or `~/.claude/settings.json` (user). Codex reads the same JSON from `.codex/hooks.json` (project; the project must be trusted) or `~/.codex/hooks.json` (user).

```json
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "/path/to/execution-coordinator/hooks/claude-stop-hook.sh" } ] }
    ],
    "PreToolUse": [
      { "matcher": "Bash",
        "hooks": [ { "type": "command", "command": "/path/to/execution-coordinator/hooks/claude-merge-gate.sh" } ] }
    ]
  }
}
```

## Quiet hours

Set `COORD_QUIET="00-07"` (local hours). The Stop hook then stays silent in that window. Schedule the sweeper outside it.

## Session names

Name every terminal tab, tmux window and agent session, so anyone can see which ones to keep.

| Prefix | Meaning | Keep? |
|---|---|---|
| `[coord] <project>` | The one coordinator for a project | Keep |
| `[exec] <project>: <task or org/repo#N>` | An executor session a coordinator started | Until its fence is met |
| `[auto] <job>` | A scheduled sweeper or other automation | Keep |
| `[done] <old name>` | Finished or replaced | Close |

A replacement takes the same name plus ` v2`, ` v3`, and so on. The highest version is the live one. Name projects by outcome, not by code names, because a code name tells a reader nothing.

## Off switches

Any one of these turns keep-alive off:

- Set the status to `done`.
- `export COORD_KEEPALIVE=0` (Stop hook only).
- Remove the sweeper schedule.

## Status report template

```text
Status <local time>
| Owner | Where | Task / PR | State | Last change | Blocker or next action |
PRs: <per PR: head, mergeable, failing and pending checks, unresolved threads, approvals, fence>
Tasks: <new action items, blocked, unowned>
Deployment: <build, rollout, validation>
Layers: L0 <...> · L1 <tower live?> · L2 <sweeper, last run>
Next coordinator action: <...>
```

- Lead with what changed. Keep the full sweep inventory below it.
- State whether each owner is active or inactive, with an `as_of` time.
- Mark items you did not re-check as stale, with their last-checked time.
- Name the running operation of each owner whose state did not change.

A sweep report covers only changes:

- owners (tower, sessions, children, hosted runs, bots) that became idle, errored, or completed with work still open;
- work newly marked local or hosted;
- memory-check results for heavy local work.

An unchanged sweep is one line. Give the full roster daily or on request.

## Offboarding

When the project closes:

1. Clear the busy lease: `status.sh set ... --busy 0`.
2. Set every dispatch to `accepted` or `abandoned`.
3. Remove the hooks, schedules and workflows the project created.
4. Close answered `decision` issues.
5. Set each session `done`, rename it `[done] <name>` and close it. In a Claude Code cloud session, use `archive_session`.
