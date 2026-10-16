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
