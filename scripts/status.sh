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
# A new dispatch records base_sha (HEAD of its worktree) and branch. The move into `--state accepted` is refused
# (exit 4) unless `ready.sh --key <key>` recorded a clean READY verdict for this key: ok, no blockers, not
# --allow-pending, on the dispatch's current pr, paths and run_id, and on the PR's current head. status.sh reads
# that head with one REST call (`gh api repos/O/R/pulls/N`) and also refuses a PR closed without merging.
# A pr, paths or run_id change clears the verdict. PR forms (URL, owner/repo#N) and path order are normalized
# first. --branch, --worktree, --base-sha and --note never clear it. On an accepted dispatch the gate does not
# run again, and pr, paths and run_id changes are refused unless --state moves it out of accepted.
# Writes hold the .coordinator/.lock symlink, whose target names its owner. A dispatch update that finds the record
# changed since it read it exits 5 ("dispatch changed; retry"). COORD_LOCK_TRIES sets the lock wait in 0.1s tries
# (default 100; 0 means one try).
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
    comm=${comm##*/}  # macOS prints the full path, Linux the bare name
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
# Portable lock (no flock on macOS). `ln -s` makes .lock and its owner ("pid.nonce") in one atomic step. A lock
# whose owner is dead, or that has no owner and is over a minute old, is cleared by one process at a time (a
# per-owner .lock.clear.* marker), which re-reads the owner before it removes it. Only the owner unlocks.
lk_tok="" tmp=""
lk_owner() { if [ -L "$1" ]; then readlink "$1"; elif [ -d "$1" ]; then echo "dir.$(cat "$1/pid" 2>/dev/null)"; fi; }
lk_alive() { kill -0 "$1" 2>/dev/null || ps -p "$1" >/dev/null 2>&1; }
lk_clear() {
  local m; m="$1.clear.$(printf '%s' "$2" | tr -c 'A-Za-z0-9.' _)"
  ln -s "$$" "$m" 2>/dev/null || return 1
  [ "$(lk_owner "$1")" != "$2" ] || rm -rf "$1"
  rm -f "$m"
}
lock() {
  local L="$dir/.lock" tries="${COORD_LOCK_TRIES:-100}" i=0 c=0 o pid
  [[ "$tries" =~ ^[0-9]+$ ]] || tries=100
  lk_tok="$$.$RANDOM$RANDOM"
  while :; do
    # A legacy lock directory: skip ln, which would make the link inside it (and refresh its age).
    if { [ ! -d "$L" ] || [ -L "$L" ]; } && ln -s "$lk_tok" "$L" 2>/dev/null; then
      [ "$(readlink "$L" 2>/dev/null)" = "$lk_tok" ] && return 0
      rm -f "$L/$lk_tok" 2>/dev/null
    fi
    [ -w "$dir" ] || { echo "status.sh: cannot lock: $dir is not writable" >&2; lk_tok=""; return 1; }
    o=$(lk_owner "$L"); pid=${o#dir.}; pid=${pid%%.*}
    if [ -n "$o" ] && [ "$c" -lt 10 ]; then
      if [[ "$pid" =~ ^[0-9]+$ ]] && ! lk_alive "$pid"; then lk_clear "$L" "$o" && { c=$((c + 1)); continue; }
      elif ! [[ "$pid" =~ ^[0-9]+$ ]] && [ -n "$(find "$L" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then
        lk_clear "$L" "$o" && { c=$((c + 1)); continue; }
      fi
    fi
    i=$((i + 1)); [ "$i" -lt "$tries" ] || break
    sleep 0.1
  done
  lk_tok=""
  if [[ "$pid" =~ ^[0-9]+$ ]] && lk_alive "$pid"; then
    echo "status.sh: $L is held by pid $pid ($(ps -o comm= -p "$pid" 2>/dev/null)); retry. If that pid is not a status.sh or ready.sh run, it was reused: remove $L" >&2
  elif [ -n "$o" ] && ! [[ "$pid" =~ ^[0-9]+$ ]]; then
    echo "status.sh: $L has no owner pid; it is cleared once it is over a minute old, or remove it if no status.sh or ready.sh is running" >&2
  else
    echo "status.sh: $L could not be cleared (owner: ${o:-none}); remove $L and $L.clear.* if no status.sh or ready.sh is running" >&2
  fi
  return 1
}
unlock() { [ -z "$lk_tok" ] || [ "$(readlink "$dir/.lock" 2>/dev/null)" != "$lk_tok" ] || rm -f "$dir/.lock"; lk_tok=""; }
cleanup() { [ -z "$tmp" ] || rm -f "$tmp" "$tmp.err"; unlock; }
trap cleanup EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
# Atomic write under the lock: jq program and args, applied to the current file. Returns 1 when the lock is not
# taken, 5 when the program raised "dispatch changed; retry", 2 for any other jq error.
write() {
  mkdir -p "$dir"
  [ -f "$dir/.gitignore" ] || printf '*\n' > "$dir/.gitignore"
  lock || return 1
  tmp=$(mktemp "$dir/.status.XXXXXX") || { tmp=""; unlock; return 1; }
  if current | jq "$@" > "$tmp" 2> "$tmp.err"; then mv "$tmp" "$file"; rm -f "$tmp.err"; tmp=""; unlock; return 0; fi
  local rc=2; ! grep -q 'dispatch changed; retry' "$tmp.err" || rc=5
  sed 's/^jq: error (at [^)]*): /status.sh: /' "$tmp.err" >&2; rm -f "$tmp" "$tmp.err"; tmp=""; unlock; return "$rc"
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
    # bind: what a READY verdict covers. PR forms normalize to "host owner repo number"; paths compare as a set.
    lib='def prkey: if type != "string" then null else ascii_downcase
           | ([capture("^(https?://)?(?<h>[^/]+)/(?<o>[^/]+)/(?<r>[^/]+)/pull/(?<n>[0-9]+)([/?#].*)?$")]
              + [capture("^((?<h>[^/\\s]+\\.[^/\\s]+)/)?(?<o>[^/#\\s]+)/(?<r>[^/#\\s]+)#(?<n>[0-9]+)$")])[0]
           | if . == null then null else "\(.h // $gh) \(.o) \(.r) \(.n)" end end;
         def bind: [(.pr | prkey), ((.paths // []) | unique), (.run_id // null)];'
    rec=$(jq -c --arg st "$dstate" --arg wt "$wt" --arg p "$paths" --arg br "$branch" --arg bs "$base" \
          --arg run "$run" --arg pr "$pr" --arg note "$note" --arg t "$now" --arg gh "${GH_HOST:-github.com}" "$lib"'
      (. // {state:"running", dispatched_at:$t}) as $old
      | ($old
          + (if $st != "" then {state:$st} else {} end)
          + (if $wt != "" then {worktree:$wt} else {} end)
          + (if $p != "" then {paths: ($p | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != "")))} else {} end)
          + (if $br != "" then {branch:$br} else {} end)
          + (if $bs != "" then {base_sha:$bs} else {} end)
          + (if $run != "" then {run_id:$run} else {} end)
          + (if $pr != "" then {pr:$pr} else {} end)
          + (if $note != "" then {note:$note} else {} end)
          + {updated_at:$t})
      | if bind == ($old | bind) then . elif $old.state == "accepted" and .state == "accepted" then error("rebind")
        else del(.ready) end' <<<"${prev:-null}" 2>&1) || {
      case "$rec" in *rebind*)
        echo "status.sh: refusing: dispatch \"$key\" is accepted; move it out of accepted with --state before changing pr, paths or run_id" >&2
        exit 4;; esac
      echo "status.sh: could not build the dispatch record: ${rec#jq: error (at <stdin>:*): }" >&2; exit 2; }
    if [ "$(jq -r .state <<<"$rec")" = "accepted" ] && [ "$(jq -r '.state // ""' <<<"$pj")" != "accepted" ]; then
      refuse() { echo "status.sh: refusing: dispatch \"$key\" $*" >&2; exit 4; }
      rerun="; run scripts/ready.sh --key $key first"
      why=$(jq -r --arg k "$key" --arg gh "${GH_HOST:-github.com}" "$lib"'
        .ready as $v
        | if ($v | type) == "object" and $v.in_progress == true then "has a READY check that did not finish"
          elif ($v | type) != "object" or $v.ok != true or $v.unreadable == true then "has no passing READY check"
          elif $v.allow_pending != false then "has a READY verdict that does not rule out --allow-pending"
          elif $v.blockers != [] then "has a READY verdict with blockers"
          elif $v.key != $k then "has a READY verdict recorded for another dispatch"
          elif (.pr | prkey) == null then "has no PR"
          elif bind != [($v.pr | prkey), (($v.paths // []) | unique), ($v.run // null)]
            then "has a READY verdict for another PR, --paths scope or run"
          else "" end' <<<"$rec")
      [ -z "$why" ] || refuse "$why$rerun"
      read -r h o r n <<<"$(jq -r --arg gh "${GH_HOST:-github.com}" "$lib"' .pr | prkey' <<<"$rec")"
      # One REST read. A merged PR keeps its last head in head.sha, so a verdict taken before the merge still binds.
      cur=$(gh api --hostname "$h" "repos/$o/$r/pulls/$n" --jq '"\(.head.sha) \(.state) \(.merged)"' 2>/dev/null) || cur=""
      read -r csha cstate cmerged <<<"$cur"
      [[ "${csha:-}" =~ ^[0-9a-f]{40}$ ]] \
        || refuse "cannot confirm the PR head: gh could not read $h/$o/$r#$n; fix gh access (auth, host or network) and retry"
      [ "$cstate" != "closed" ] || [ "$cmerged" = "true" ] || refuse "PR is closed without merging"
      [ "$csha" = "$(jq -r '.ready.head' <<<"$rec")" ] || refuse "PR head moved to ${csha:0:9} after READY$rerun"
    fi
    # Compare-and-swap: write only if the record is still the one read above.
    write --arg k "$key" --argjson prev "${prev:-null}" --argjson rec "$rec" '
      if (.dispatches[$k] // null) != $prev then error("dispatch changed; retry (\"\($k)\" was updated while this ran)")
      else . end
      | .dispatches = (.dispatches // {}) | .dispatches[$k] = $rec' || exit $?
    jq -r --arg k "$key" '.dispatches[$k] | "dispatch \($k): \(.state)\(if .base_sha then " base \(.base_sha[0:9])" else "" end)"' "$file"
    ;;
  *)
    sed -n '2,7p' "$0"; exit 2
    ;;
esac
