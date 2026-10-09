# Keep-alive, status and reports

You must read this at the kickoff of any coordination and on every resume, as SKILL.md requires. Read it again before you set a status, write a `human-gate` or a decision issue, set up the L2 sweeper, install a hook, name sessions, write a status report, turn keep-alive off, or offboard a finished project.

## Contents

- Bundled tools
- Operating layers
- Status commands
- Rules for every agent
- Decision issues
- One coordinator per project
- Enforcers
- The L2 sweeper
- Install the hooks
- Quiet hours
- Session names
- Off switches
- Status report template
- Offboarding

## Bundled tools

- `scripts/status.sh`: session status, busy lease and dispatch records.
- `scripts/ready.sh`: the READY check for one PR on one head.
- `scripts/pr-threads.sh`: the review-thread audit.
- `hooks/claude-stop-hook.sh` (keep-alive), `hooks/claude-merge-gate.sh` (merge gate) and `hooks/session-start.sh` (re-orients a new, resumed or compacted session).

Set `GH_HOST` for GitHub Enterprise.

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
   A nudge that quotes another session's status text means two sessions share a worktree and the nudge was misrouted. Do not answer "no change" to every nudge: one such file drew 55 nudges and 15 idle flags in 4 hours. Find the session that writes the file from its `set` history, not from titles or the recorded owner, which can be a stale claim. Message it, name the file, ask it to set the true state (`waiting` or `human-gate`), and end the turn; relay again at the next nudge instead of going silent. Never edit or claim its file.
   The sweeper follows the same rule. It sends a status file's nudges to the coordinator session that writes the file, never to an executor that only shares the worktree, and it names the file in the message. A nudge is not a takeover: the sweeper never claims a file whose owner was active in the last 30 minutes. Only that much silence, or an explicit arm by the new owner, transfers it.
7. Before a scheduled gap or quiet hours, set `waiting` with a precise next action.

Observation-only sessions have no keep-alive.

## Decision issues

A human decision is a real choice between options only. Credentials, review waits and one-answer fixes are not decisions.

1. Open one GitHub issue per decision, labelled `decision`, with the options, your recommendation and the cost if wrong.
2. Link it from the ledger and from the `human-gate` status.
3. Close it with the named person's answer.

## One coordinator per project

SKILL.md holds the rule: find and message the live coordinator instead of starting a second coordinator or sweeper. The detail:

- If you find two, both stop writing. The one the ledger names keeps the project; if the ledger names neither, the older one keeps it. The other hands over.
- Silence never transfers ownership.
- Retire executors as their tasks finish (MERGE step 5 in SKILL.md).
- Each sweep archives idle sessions whose tasks are all `accepted` or `abandoned`.

## Enforcers

| Enforcer | Behavior |
|---|---|
| Claude Code or Codex Stop hook (`hooks/claude-stop-hook.sh`) | While the status is `active`, it blocks the stop and feeds back the next action. It releases the session after 8 blocks with no change to state, next action, HEAD or worktree. `status.sh set` resets the count. It skips a different owner only when both `owner_session` and the hook's `session_id` exist, so set `$CLAUDE_CODE_SESSION_ID` (Codex: `$CODEX_THREAD_ID`); the nearest agent process wins. A live busy lease makes it stand down. |
| Claude Code or Codex SessionStart hook (`hooks/session-start.sh`) | While the status is `active`, `waiting` or `human-gate`, it re-orients a new, resumed or compacted session: state, next action, open dispatches, and read the skill and ledger first. It never blocks. |
| L2 sweeper | Nudges idle `active` sessions, and `waiting` sessions whose recheck is due, through their terminal or a headless resume. |
| Other harnesses | Use the harness's own continuation hook if it has one. Otherwise rely on the sweeper. |

## The L2 sweeper

Run one sweeper per project; it acts as the project's one logical owner. It is a scheduled headless CLI run or a GitHub Actions `on: schedule` workflow. Each run reads the skill, the ledger and the backlog, runs the sweep from SKILL.md, nudges idle owners as the keep-alive protocol says, and syncs the ledger mirror. It respects `--busy` leases and never overlaps a previous run, because two sweeps would make conflicting writes.

```bash
# crontab -e: weekdays every 10 min, 08:00–18:59
*/10 8-18 * * 1-5  cd ~/src/project && claude -p "Read execution-coordinator and ledger; run the sweep; respect busy leases; nudge idle owners per the keep-alive protocol; sync mirror." >> .coordinator/sweep.log 2>&1
# Codex: same line with  codex exec --sandbox workspace-write -c sandbox_workspace_write.network_access=true "Use \$execution-coordinator ..."
```

Other headless CLIs work too. Record every schedule in the ledger, and remove it when the project closes.

## Install the hooks

Put this in `.claude/settings.json` (project) or `~/.claude/settings.json` (user). Codex reads the same JSON from `.codex/hooks.json` (project; the project must be trusted) or `~/.codex/hooks.json` (user).

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup|resume|clear|compact",
        "hooks": [ { "type": "command", "command": "/path/to/execution-coordinator/hooks/session-start.sh" } ] }
    ],
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

The SessionStart hook (`hooks/session-start.sh`) adds context only while `.coordinator/status.json` is `active`, `waiting` or `human-gate`. It gives the state, next action and open dispatches, and tells the session to read this skill and the ledger before it acts. After `resume` or `compact` it also says to run the sweep first. When `owner_session` names another session, or this session has no `session_id`, it says not to take over and to message the owner. With no status or a `done` status it prints nothing, so other sessions pay no context cost. `COORD_SESSION_START=0` turns it off. `COORD_SESSION_START=always` also prints a one-line pointer to the skill when no status exists. A claude.ai/code cloud session loads hooks only from the repo's `.claude/settings.json`, so put the entry there and use a path inside the checkout.

### Per-repo install (cloud sessions and shared repos)

A cloud session keeps no home folder, and the skill's path differs between machines. So put a small resolver in the repo instead of a fixed path. Save it as `.claude/hooks/coordinator.sh` and make it executable. It finds the installed skill, runs the requested hook, and prints nothing when no copy is installed:

```bash
#!/usr/bin/env bash
# Runs one execution-coordinator hook (session-start or stop) from wherever the skill is installed.
# Usage, from .claude/settings.json or .codex/hooks.json: coordinator.sh <session-start|stop>
# The hook reads the harness JSON on stdin; this script passes stdin through untouched.
# Search order: $COORD_SKILL_DIR, this repo if it is the skill itself, ~/.claude/skills,
# claude.ai synced skills (cloud sessions), ~/.agents/skills (Codex). The first copy that ships the
# requested hook wins. With no copy installed, it reads stdin and exits 0, so a session never breaks.
# Both hooks print nothing unless <repo>/.coordinator/status.json shows a coordination in progress.
set -u
case "${1:-}" in
  session-start) file=session-start.sh ;;
  stop) file=claude-stop-hook.sh ;;
  *) cat >/dev/null; exit 0 ;;
esac
root=$(git rev-parse --show-toplevel 2>/dev/null || true)
for dir in "${COORD_SKILL_DIR:-}" "$root" "$HOME/.claude/skills/execution-coordinator" \
           "$HOME"/.claude/skills/synced/*/execution-coordinator "$HOME/.agents/skills/execution-coordinator"; do
  [ -n "$dir" ] && [ -f "$dir/hooks/$file" ] && grep -qs '^name: execution-coordinator$' "$dir/SKILL.md" \
    && exec bash "$dir/hooks/$file"
done
cat >/dev/null
exit 0
```

Then point both harnesses at it. In `.claude/settings.json` use `"$CLAUDE_PROJECT_DIR"/.claude/hooks/coordinator.sh session-start` (matcher `startup|resume|clear|compact`) and `... coordinator.sh stop`. In `.codex/hooks.json` use `bash "$(git rev-parse --show-toplevel)/.claude/hooks/coordinator.sh" session-start` and `... stop`. Add the merge gate the same way only if the repo's merge rules should require `ready.sh`, because it blocks every `gh pr merge` that fails READY. This repository and `mejasonmejason/tootsies` use this setup.

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
- `export COORD_SESSION_START=0` (SessionStart hook only).
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
- Link every piece of evidence (PRs, threads, checks, tasks, docs, deploys, runs, sessions) descriptively, with a real URL.
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
