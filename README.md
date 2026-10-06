# execution-coordinator

A skill for Claude and Codex that acts as a control tower for multi-PR engineering work. It plans the work, sends tasks to executor sessions, checks every claim of "done" against git, and merges only what passes its gates.

## What is in this repository

| Path | What it does |
|---|---|
| `SKILL.md` | The skill. Claude or Codex reads it when the skill triggers. |
| `scripts/ready.sh` | Checks the READY fence for one PR on one head SHA. Exit 0 ready, 1 not ready, 3 unreadable. |
| `scripts/pr-threads.sh` | Lists review feedback as ACTION, AWAITING or UNSENT. Falls back to REST where GitHub GraphQL is refused. |
| `scripts/status.sh` | Keeps a session's status, busy lease and dispatch records. |
| `hooks/claude-merge-gate.sh` | PreToolUse hook for Claude Code and Codex. Blocks a merge unless `ready.sh` passes. |
| `hooks/claude-stop-hook.sh` | Stop hook for Claude Code and Codex. Keeps the owning session working while its status is active. |
| `tests/run.sh` | Offline test suite. `gh` is replaced by a stub, so nothing touches GitHub. |
| `agents/openai.yaml` | Codex display name, short description and default prompt. |

## Release and install

Every merge to `main` runs `.github/workflows/skill.yml`. It runs the tests and the upload checks, builds `execution-coordinator.zip`, and publishes it as a GitHub Release with its sha256.

- **claude.ai:** download `execution-coordinator.zip` from the [latest release](../../releases/latest) and upload it on the Skills page in place of the current skill. claude.ai has no API for account skills, so this step stays manual.
- **Claude Code:** copy the folder into `~/.claude/skills/` or into a repository's `.claude/skills/`.
- **Codex:** copy the folder into `~/.agents/skills/` or into a repository's `.agents/skills/`. Start it with `$execution-coordinator`, or let Codex pick it from the description.
- **Hooks (optional):** add the two hooks to `.claude/settings.json` (Claude Code) or `.codex/hooks.json` (Codex). Both use the same JSON entry; `SKILL.md` section 8a has it. Codex loads project hooks only when the project is trusted.

## Change

1. Open a PR. The workflow runs the tests and the upload checks on it.
2. Merge the PR. The workflow publishes a new release.
3. Upload the release zip on claude.ai.

## Test

```bash
bash tests/run.sh   # 87 cases, offline; exit 0 when all pass
```

Run the suite before and after every change. A rule that a script can enforce gets a test case.

## Version history

| Version | Change |
|---|---|
| v1 | Internal tools replaced by git, the GitHub CLI, GitHub Actions and cron. |
| v2 | `ready.sh`, the merge gate, clean-room acceptance, the test suite. |
| v3 | Claude Code cloud mapping and the `send_message` rules. |
| v4 | Risk floor from changed paths, read-only reviewers, flake versus caused, task buckets. |
| v5 | 20% shorter; one home per rule; contradictions fixed. |
| v6 | Scale process to risk, merge-queue bisection, idempotent writes, milestones, canaries. Plus the REST fallback for cloud sessions and archiving of finished executor sessions. |
| v7 | 12% shorter with the same rules. Plans and reports use the fewest plain steps the risk needs, with one worked example. In head-to-head tests this cut average answer length from about 165 words to 158. |
| v8 | Credentials stay with the owner, who is asked directly; decision issues only for real choices. Seven rules from the internal version: sweep after compaction, drift checks on long-running writers, 10-minute checkpoints, mobile widths, checking discovery before trusting zero, one heavy local job at a time, stack pushes through the stack tool. |
| v10 | Codex support. The hooks run unchanged under Codex hooks. `status.sh` takes the session owner from `$CODEX_THREAD_ID` when `$CLAUDE_CODE_SESSION_ID` is not set. `SKILL.md` §0a maps executors, resume, sandbox network and hooks to Codex. CI checks `agents/openai.yaml`. |
| v9 | Review effort scales with risk: advisors, scouts and extra reviewers only for high risk or real uncertainty; three-reviewer acceptance stays for auth, security, payments, ledger, data migrations, infrastructure and weakened gates. Bookkeeping is implied in plans. Restores rules a rule-by-rule audit found weakened, settles who keeps a project when two coordinators collide, and fixes the heavy-local-job contradiction. Same size. In head-to-head tests efficiency rose from 3.86 to 4.02 of 5. |
