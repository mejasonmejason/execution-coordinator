#!/usr/bin/env bash
# SessionStart hook for execution-coordinator. Works in Claude Code and Codex (same input and output format).
# Claude Code: add to .claude/settings.json (project) or ~/.claude/settings.json (user).
# Codex: add to .codex/hooks.json (project; the project must be trusted) or ~/.codex/hooks.json (user).
#   { "hooks": { "SessionStart": [ { "matcher": "startup|resume|clear|compact", "hooks": [ { "type": "command",
#       "command": "/path/to/execution-coordinator/hooks/session-start.sh" } ] } ] } }
# When <git root>/.coordinator/status.json says active, waiting or human-gate, the hook adds a short context note:
# the state, next action, dispatches, and the instruction to read the skill and the ledger before acting. After
# resume or compact it also says to run the sweep first. When owner_session is set and differs from this session_id,
# the note says another session owns the coordination and this session must not take over or write the status.
# With no status, or state done, it prints nothing, so the skill costs no context in other sessions.
# Off: export COORD_SESSION_START=0. COORD_SESSION_START=always also prints a one-line pointer to the skill when
# no coordination is in progress. Fails open: any error prints nothing and exits 0, so it never blocks a session.
set -uo pipefail

main() {
  local input cwd sid src root file mode
  input=$(cat)
  mode="${COORD_SESSION_START:-1}"
  [ "$mode" = "0" ] && return 0
  cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null) || cwd=""
  [ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
  sid=$(jq -r '.session_id // empty' <<<"$input" 2>/dev/null) || sid=""
  src=$(jq -r '.source // empty' <<<"$input" 2>/dev/null) || src=""
  file=""
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) && file="$root/.coordinator/status.json"

  if [ -n "$file" ] && [ -f "$file" ] && [ -r "$file" ]; then
    jq -c --arg sid "$sid" --arg src "$src" '
      def cut($n): if length > $n then .[0:$n - 3] + "..." else . end;
      select(type == "object" and (.state | IN("active", "waiting", "human-gate")))
      | (.dispatches // {} | if type == "object" then to_entries else [] end
         | map({k: .key, s: (.value.state // "running"), pr: (.value.pr // "")})) as $d
      | ($d | map(.s) | group_by(.) | map("\(length) \(.[0])") | join(", ")) as $counts
      | ($d | map(select(.s | IN("accepted", "abandoned") | not))
         | map("\(.k | cut(40)) (\(.s)\(if .pr != "" then ", " + (.pr | cut(80)) else "" end))")) as $open
      | ((.owner_session // "") as $o | $o != "" and $sid != "" and $o != $sid) as $other
      | ("Coordination in progress in this repository (execution-coordinator). State: \(.state). "
         + "Next action: \(.next_action // "none" | cut(300)). Last update: \(.updated_at // "unknown")."
         + (if (.busy_until // "") != "" then " Busy until \(.busy_until)." else "" end)
         + (if ($d | length) > 0 then " Dispatches: \($counts)." else "" end)) as $head
      | (if $other then
           " Another session owns this coordination (\(.owner_session | cut(60))). Do not take it over and do not"
           + " write its status. Message the owner instead: there is one coordinator per project."
         else
           " Before acting, read the execution-coordinator skill and the coordinator ledger."
           + (if $src | IN("resume", "compact") then
                " This session was resumed or compacted: run the sweep first (rediscover PRs, reconcile owners,"
                + " check READY), then act and update the status with scripts/status.sh."
              else "" end)
         end) as $tail
      # Fit the open dispatches into what is left of a 1,200-character budget.
      | (1200 - ($head + $tail | length) - 30) as $room
      | (reduce $open[] as $x ({items: [], len: 0};
           if .full then . elif .len + ($x | length) + 2 <= $room then .items += [$x] | .len += ($x | length) + 2
           else .full = true end)) as $fit
      | (if ($open | length) == 0 then ""
         else " Open: " + ($fit.items | join("; "))
           + (if ($open | length) > ($fit.items | length)
              then "\(if ($fit.items | length) > 0 then "; " else "" end)and \(($open | length) - ($fit.items | length)) more"
              else "" end) + "."
         end) as $list
      | {hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: ($head + $list + $tail)}}
    ' "$file" 2>/dev/null && return 0
  fi

  if [ "$mode" = "always" ]; then
    jq -cn '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext:
      "The execution-coordinator skill is installed: use it for multi-PR, multi-agent or multi-session delivery work."}}'
  fi
}

out=$(main 2>/dev/null) || out=""
# Print only one valid JSON object; anything else is dropped (fail open).
if [ -n "$out" ] && jq -e 'type == "object"' >/dev/null 2>&1 <<<"$out"; then printf '%s\n' "$out"; fi
exit 0
