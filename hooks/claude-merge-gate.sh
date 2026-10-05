#!/usr/bin/env bash
# Claude Code PreToolUse merge gate for execution-coordinator.
# Add to .claude/settings.json (project) or ~/.claude/settings.json (user):
#   { "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command",
#       "command": "/path/to/execution-coordinator/hooks/claude-merge-gate.sh" } ] } ] } }
# On `gh pr merge` (not --disable-auto) or `gh api .../pulls/N/merge`, it resolves the PR and runs scripts/ready.sh
# on the current head (--allow-pending for --auto). Exit 0 allows; exit 2 blocks with the reason on stderr.
# Fails closed when the PR cannot be resolved or read. It only checks; it never runs the merge.
# Override after verifying a blocker is wrong: prefix the command with COORD_READY_OVERRIDE="<reason>".
# Overrides are allowed and appended to <git root>/.coordinator/overrides.log; report them.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ready="$here/../scripts/ready.sh"
input=$(cat)
command=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
[ -n "$command" ] || exit 0

# One JSON object per merge found: {selector, repo, auto}. Mirrors how gh parses its arguments closely enough
# to find the PR; anything it cannot place is resolved by `gh pr view` in the session's directory.
targets=$(jq -rn --arg cmd "$command" --arg host "${GH_HOST:-github.com}" '
  def strip: sub("^[\"\u0027]"; "") | sub("[\"\u0027]$"; "");
  $cmd | splits("&&|\\|\\||;|\n|\\|")
  | . as $seg
  | [ scan("(?:\"[^\"]*\"|\u0027[^\u0027]*\u0027|\\S)+") ] as $t
  | ([ range(0; $t | length) | select(($t[.] | test("(^|/)gh$")) and $t[. + 1] == "pr" and $t[. + 2] == "merge") ][0]) as $gi
  | if $gi != null then
      ($t[$gi + 3:] | map(strip)) as $a
      | if ($a | index("--disable-auto")) != null then empty else
          (reduce range(0; $a | length) as $i ({skip: false, repo: null, sel: null};
             if .skip then .skip = false
             elif $a[$i] == "-R" or $a[$i] == "--repo" then .repo = $a[$i + 1] | .skip = true
             elif ($a[$i] | startswith("--repo=")) then .repo = $a[$i][7:]
             elif ($a[$i] | test("^-(b|t|F|-body|-subject|-body-file|-match-head-commit|-author-email)$")) then .skip = true
             elif ($a[$i] | startswith("-") | not) and .sel == null then .sel = $a[$i]
             else . end))
          | {selector: .sel, repo: .repo, auto: (($a | index("--auto")) != null)} | @json
        end
    elif ([ range(0; $t | length) | select(($t[.] | test("(^|/)gh$")) and $t[. + 1] == "api") ] | length) > 0
         and ($seg | test("repos/[^/\\s\"\u0027]+/[^/\\s\"\u0027]+/pulls/[0-9]+/merge\\b")) then
      ($seg | capture("repos/(?<o>[^/\\s\"\u0027]+)/(?<r>[^/\\s\"\u0027]+)/pulls/(?<n>[0-9]+)/merge")) as $m
      | (([ $seg | capture("--hostname[ =](?<h>[^\\s\"\u0027]+)") | .h ][0]) // $host) as $h
      | {selector: "https://\($h)/\($m.o)/\($m.r)/pull/\($m.n)", repo: null, auto: false} | @json
    else empty end' 2>/dev/null) || targets=""
if [ -z "$targets" ]; then
  # Parse failure on a command that mentions a merge must not slip through.
  if grep -qE 'gh[[:space:]]+pr[[:space:]]+merge|pulls/[0-9]+/merge' <<<"$command" && ! grep -q -- '--disable-auto' <<<"$command"; then
    echo "[merge gate] Could not parse which PR this command merges; pass the PR URL explicitly." >&2; exit 2
  fi
  exit 0
fi

if [[ "$command" =~ COORD_READY_OVERRIDE=(\"([^\"]+)\"|\'([^\']+)\'|([^[:space:]]+)) ]]; then
  reason="${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
  mkdir -p "$root/.coordinator" 2>/dev/null && { [ -f "$root/.coordinator/.gitignore" ] || printf '*\n' > "$root/.coordinator/.gitignore"; }
  printf '%s\toverride\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$reason" "$(tr '\n' ' ' <<<"$command" | head -c 300)" \
    >> "$root/.coordinator/overrides.log" 2>/dev/null \
    || echo "[merge gate] warning: could not write $root/.coordinator/overrides.log" >&2
  echo "[merge gate] override accepted: $reason (logged; include it in the next report)" >&2
  exit 0
fi

fails=""
while IFS= read -r t; do
  [ -n "$t" ] || continue
  sel=$(jq -r '.selector // empty' <<<"$t"); repo=$(jq -r '.repo // empty' <<<"$t"); auto=$(jq -r '.auto' <<<"$t")
  if [[ "$sel" =~ ^https?://[^/]+/[^/]+/[^/]+/pull/[0-9]+ ]] || [[ "$sel" =~ ^([^/[:space:]]+/)?[^/#[:space:]]+/[^/#[:space:]]+#[0-9]+$ ]]; then
    url="$sel"
  else
    args=(pr view); [ -n "$sel" ] && args+=("$sel"); [ -n "$repo" ] && args+=(-R "$repo")
    url=$(cd "$cwd" && gh "${args[@]}" --json url -q .url 2>/dev/null) || url=""
  fi
  if [ -z "$url" ]; then
    fails+="could not resolve which PR \"$(head -c 120 <<<"$command")\" merges; pass the PR URL explicitly"$'\n'
    continue
  fi
  flags=(); [ "$auto" = "true" ] && flags+=(--allow-pending)
  out=$(cd "$cwd" && "$ready" "$url" ${flags[@]+"${flags[@]}"} 2>&1); rc=$?
  case "$rc" in
    0) ;;
    1) fails+="$out"$'\n';;
    *) fails+="READY check unreadable for $url (fail closed): $out"$'\n';;
  esac
done <<<"$targets"

[ -z "$fails" ] && exit 0
{
  echo "[merge gate] Merge blocked; the READY fence is not met."
  printf '%s' "$fails"
  echo 'Fix the blockers and retry. If a blocker is verifiably wrong (for example a stale or misread check), re-run with COORD_READY_OVERRIDE="<reason>" prefixed to the command; overrides are logged and must be reported.'
} >&2
exit 2
