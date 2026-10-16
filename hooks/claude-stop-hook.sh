#!/usr/bin/env bash
# Stop hook for execution-coordinator keep-alive. Works in Claude Code and Codex (same input and output format).
# Claude Code: add to .claude/settings.json (project) or ~/.claude/settings.json (user).
# Codex: add to .codex/hooks.json (project; the project must be trusted) or ~/.codex/hooks.json (user).
#   { "hooks": { "Stop": [ { "hooks": [ { "type": "command",
#       "command": "/path/to/execution-coordinator/hooks/claude-stop-hook.sh" } ] } ] } }
# When <git root>/.coordinator/status.json says "active", the hook blocks the stop and feeds back the
# next action. It gives up after 8 stops with no change to state, next action, HEAD, or working tree.
# It never blocks a different session: when the status records owner_session (set by scripts/status.sh from
# the nearest claude or codex process) and this hook's session_id differs, the stop goes through. It also stands down while
# busy_until (status.sh set ... --busy N) is in the future.
# Off: export COORD_KEEPALIVE=0. Quiet hours: export COORD_QUIET="00-07" (local hours, start-end).
set -uo pipefail

input=$(cat)
[ "${COORD_KEEPALIVE:-1}" = "0" ] && exit 0

if [ -n "${COORD_QUIET:-}" ]; then
  start=${COORD_QUIET%-*}; end=${COORD_QUIET#*-}; h=$(date +%H)
  if [ "$((10#$h))" -ge "$((10#$start))" ] && [ "$((10#$h))" -lt "$((10#$end))" ]; then exit 0; fi
fi

cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null); cwd=${cwd:-$PWD}
root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
file="$root/.coordinator/status.json"
[ -f "$file" ] || exit 0
state=$(jq -r '.state // empty' "$file"); next=$(jq -r '.next_action // empty' "$file")
[ "$state" = "active" ] || exit 0
sid=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null)
owner=$(jq -r '.owner_session // empty' "$file")
[ -n "$owner" ] && [ -n "$sid" ] && [ "$owner" != "$sid" ] && exit 0
[ "$(jq -r '(.busy_until // "") > (now | todate)' "$file")" = "true" ] && exit 0

fp=$(printf '%s|%s|%s|%s' "$state" "$next" "$(git -C "$root" rev-parse HEAD 2>/dev/null)" \
      "$(git -C "$root" status --porcelain 2>/dev/null | shasum | cut -c1-12)")
cfile="$root/.coordinator/stop-count"
prev=$(cut -d' ' -f2- "$cfile" 2>/dev/null); count=$(cut -d' ' -f1 "$cfile" 2>/dev/null || echo 0)
if [ "$prev" = "$fp" ]; then count=$((count + 1)); else count=1; fi
printf '%s %s\n' "$count" "$fp" > "$cfile"
if [ "$count" -gt 8 ]; then exit 0; fi   # stalled: let the stop through; the sweeper takes over

reason="Keep-alive: status is active. Next action: ${next}. Do it now. Before ending the turn, update status with scripts/status.sh (active, waiting, human-gate, or done)."
jq -n --arg r "$reason" '{decision:"block", reason:$r}'
