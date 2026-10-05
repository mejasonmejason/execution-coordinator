# execution-coordinator

A Claude skill that acts as a control tower for multi-PR engineering work. It plans the work, sends tasks to executor sessions, checks every claim of "done" against git, and merges only what passes its gates.

## What is in this repository

| Path | What it does |
|---|---|
| `SKILL.md` | The skill. Claude reads it when the skill triggers. |
| `scripts/ready.sh` | Checks the READY fence for one PR on one head SHA. Exit 0 ready, 1 not ready, 3 unreadable. |
| `scripts/pr-threads.sh` | Lists review feedback as ACTION, AWAITING or UNSENT. Falls back to REST where GitHub GraphQL is refused. |
| `scripts/status.sh` | Keeps a session's status, busy lease and dispatch records. |
| `hooks/claude-merge-gate.sh` | Claude Code PreToolUse hook. Blocks a merge unless `ready.sh` passes. |
| `hooks/claude-stop-hook.sh` | Claude Code Stop hook. Keeps the owning session working while its status is active. |
| `tests/run.sh` | Offline test suite. `gh` is replaced by a stub, so nothing touches GitHub. |
| `agents/openai.yaml` | Metadata for Codex. |

## Install

- **claude.ai:** zip the repository folder as `execution-coordinator/` and upload it on the Skills page.
- **Claude Code:** copy the folder into `~/.claude/skills/` or into a repository's `.claude/skills/`.
- **Hooks (optional):** add the two hooks to `.claude/settings.json`. `SKILL.md` section 8a has the entry.

## Test

```bash
bash tests/run.sh   # 82 cases, offline; exit 0 when all pass
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
