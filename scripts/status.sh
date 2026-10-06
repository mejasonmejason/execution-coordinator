#!/usr/bin/env bash
# Keep-alive status and dispatch records for execution-coordinator.
#   status.sh set <active|waiting|human-gate|done> "<next action>" [--recheck MINUTES] [--busy MINUTES]
#   status.sh get
#   status.sh dispatch                      list dispatch records
#   status.sh dispatch <key> [--state running|awaiting-acceptance|accepted|rejected|abandoned]
#       [--worktree DIR] [--paths "a/**,b/*.ts"] [--branch B] [--base-sha S] [--run-id R] [--pr URL] [--note T]
# Writes <git root>/.coordinator/status.json (git-ignored). Refuses $HOME and non-git directories.
# --busy N sets busy_until N minutes ahead (0 clears): the Stop hook and the sweeper stand down until then.
# owner_session is the session id of the nearest claude or codex ancestor process ($CLAUDE_CODE_SESSION_ID or
# $CODEX_THREAD_ID), because a child inherits its parent's variable. $COORD_SESSION_ID overrides it. The Stop hook
# only blocks that session.
# A new dispatch records base_sha (HEAD of its worktree) and branch. `--state accepted` is refused unless
# `ready.sh --key <key>` has recorded a passing READY check for that dispatch.
set -euo pipefail

root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "status.sh: not inside a git repository" >&2; exit 2; }
home_real=$(cd "$HOME" 2>/dev/null && pwd -P || echo "$HOME")
{ [ "$root" = "$HOME" ] || [ "$root" = "$home_real" ]; } && { echo "status.sh: refusing to write in \$HOME" >&2; exit 2; }
dir="$root/.coordinator"
file="$dir/status.json"
now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Session id of the agent that runs this script. The nearest claude or codex ancestor decides which variable is
# its own; the other one can be inherited from a parent agent. With no such ancestor, Claude's id comes first.
session_id() {
  [ -n "${COORD_SESSION_ID:-}" ] && { echo "$COORD_SESSION_ID"; return; }
  local pid=$PPID comm i
  for i in $(seq 1 30); do
    comm=$(ps -o comm= -p "$pid" 2>/dev/null) || break
    case "$comm" in
      codex*) [ -n "${CODEX_THREAD_ID:-}" ] && { echo "$CODEX_THREAD_ID"; return; }; break;;
      claude*) [ -n "${CLAUDE_CODE_SESSION_ID:-}" ] && { echo "$CLAUDE_CODE_SESSION_ID"; return; }; break;;
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ "${pid:-0}" -gt 1 ] || break
  done
  echo "${CLAUDE_CODE_SESSION_ID:-${CODEX_THREAD_ID:-}}"
}
current() { if [ -f "$file" ]; then cat "$file"; else echo '{}'; fi; }
# Atomic write: jq program and args, applied to the current file.
write() {
  mkdir -p "$dir"
  [ -f "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore"
  local tmp; tmp=$(mktemp "$dir/.status.XXXXXX")
  if current | jq "$@" > "$tmp"; then mv "$tmp" "$file"; else rm -f "$tmp"; return 1; fi
}
need() { [ "$1" -ge 2 ] || { echo "status.sh: $2 needs a value" >&2; exit 2; }; }

case "${1:-}" in
  get)
    [ -f "$file" ] && cat "$file" || echo '{"state":"none"}'
    ;;
  set)
    state="${2:-}"; next="${3:-}"; shift 3 || true
    case "$state" in active|waiting|human-gate|done) ;; *) echo "status.sh: state must be active|waiting|human-gate|done" >&2; exit 2;; esac
    [ -n "$next" ] || { echo "status.sh: next action required" >&2; exit 2; }
    recheck=10; busy=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --recheck) need $# "$1"; recheck="$2"; shift 2;;
        --busy) need $# "$1"; busy="$2"; shift 2;;
        *) echo "status.sh: unknown flag $1" >&2; exit 2;;
      esac
    done
    [[ "$recheck" =~ ^[0-9]+$ ]] || { echo "status.sh: --recheck takes whole minutes" >&2; exit 2; }
    [ -z "$busy" ] || [[ "$busy" =~ ^[0-9]+$ ]] || { echo "status.sh: --busy takes whole minutes (0 clears)" >&2; exit 2; }
    head=$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo none)
    write --arg s "$state" --arg n "$next" --argjson r "$recheck" --arg h "$head" \
          --arg o "${AGENT_SESSION_NAME:-}" --arg os "$(session_id)" --arg t "$now" --arg b "$busy" '
      . + {state:$s, next_action:$n, recheck_minutes:$r, head:$h, owner:$o, updated_at:$t}
      | if $os != "" then .owner_session = $os else del(.owner_session) end
      | if $b == "" then . elif ($b|tonumber) > 0 then .busy_until = (now + ($b|tonumber) * 60 | floor | todate) else del(.busy_until) end
      | if (.busy_until // "") != "" and .busy_until <= $t then del(.busy_until) else . end'
    rm -f "$dir/stop-count"
    busy_until=$(jq -r '.busy_until // empty' "$file")
    echo "status: $state -> $file${busy_until:+ (busy until $busy_until)}"
    ;;
  dispatch)
    shift
    if [ $# -eq 0 ]; then current | jq '.dispatches // {}'; exit 0; fi
    key="$1"; shift
    case "$key" in -*|"") echo "status.sh: dispatch needs a key first" >&2; exit 2;; esac
    dstate="" wt="" paths="" branch="" base="" run="" pr="" note=""
    while [ $# -gt 0 ]; do
      need $# "$1"
      case "$1" in
        --state) dstate="$2";; --worktree) wt="$2";; --paths) paths="$2";; --branch) branch="$2";;
        --base-sha) base="$2";; --run-id) run="$2";; --pr) pr="$2";; --note) note="$2";;
        *) echo "status.sh: unknown flag $1" >&2; exit 2;;
      esac
      shift 2
    done
    case "$dstate" in ""|running|awaiting-acceptance|accepted|rejected|abandoned) ;;
      *) echo "status.sh: --state must be running|awaiting-acceptance|accepted|rejected|abandoned" >&2; exit 2;; esac
    prev=$(current | jq -c --arg k "$key" '.dispatches[$k] // empty')
    pj="$prev"; [ -n "$pj" ] || pj='{}'
    [ -n "$wt" ] || wt=$(jq -r '.worktree // empty' <<<"$pj")
    gitdir="${wt:-$root}"
    if [ -z "$prev" ]; then
      [ -n "$base" ] || base=$(git -C "$gitdir" rev-parse HEAD 2>/dev/null || true)
      [ -n "$branch" ] || branch=$(git -C "$gitdir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
    fi
    final="${dstate:-$(jq -r '.state // "running"' <<<"$pj")}"
    if [ "$final" = "accepted" ] && [ "$(jq -r '.ready.ok // false' <<<"$pj")" != "true" ]; then
      echo "status.sh: refusing: dispatch \"$key\" has no passing READY check; run scripts/ready.sh --key $key first" >&2
      exit 4
    fi
    write --arg k "$key" --arg st "$dstate" --arg wt "$wt" --arg p "$paths" --arg br "$branch" --arg bs "$base" \
          --arg run "$run" --arg pr "$pr" --arg note "$note" --arg t "$now" '
      .dispatches = (.dispatches // {})
      | .dispatches[$k] = ((.dispatches[$k] // {state:"running", dispatched_at:$t})
          + (if $st != "" then {state:$st} else {} end)
          + (if $wt != "" then {worktree:$wt} else {} end)
          + (if $p != "" then {paths: ($p | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != "")))} else {} end)
          + (if $br != "" then {branch:$br} else {} end)
          + (if $bs != "" then {base_sha:$bs} else {} end)
          + (if $run != "" then {run_id:$run} else {} end)
          + (if $pr != "" then {pr:$pr} else {} end)
          + (if $note != "" then {note:$note} else {} end)
          + {updated_at:$t})'
    jq -r --arg k "$key" '.dispatches[$k] | "dispatch \($k): \(.state)\(if .base_sha then " base \(.base_sha[0:9])" else "" end)"' "$file"
    ;;
  *)
    sed -n '2,7p' "$0"; exit 2
    ;;
esac
