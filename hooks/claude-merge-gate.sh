#!/usr/bin/env bash
# PreToolUse merge gate for execution-coordinator. Works in Claude Code and Codex (same input and output format).
# Claude Code: add to .claude/settings.json (project) or ~/.claude/settings.json (user).
# Codex: add to .codex/hooks.json (project; the project must be trusted) or ~/.codex/hooks.json (user).
#   { "hooks": { "PreToolUse": [ { "matcher": "Bash", "hooks": [ { "type": "command",
#       "command": "/path/to/execution-coordinator/hooks/claude-merge-gate.sh" } ] } ] } }
# On `gh pr merge` (not --disable-auto) or `gh api .../pulls/N/merge`, it resolves the PR and runs scripts/ready.sh
# on the current head (--allow-pending for --auto). Exit 0 allows; exit 2 blocks with the reason on stderr.
# gh flags before `pr` or `merge` (-R/--repo, --hostname) are understood; any other flag there fails closed.
# Fails closed when the PR cannot be resolved or read. It only checks; it never runs the merge.
# Override after verifying a blocker is wrong: prefix the command with COORD_READY_OVERRIDE="<reason>".
# Only a leading assignment of the merge command counts (`env` and its -i/-u/-C/-- options may come first); the same
# text inside an argument does not. A merge in a subshell or a $(...) substitution is still checked; pr ... merge after
# a variable or substitution in command position ($GH pr merge 5) fails closed.
# Overrides are allowed and appended to <git root>/.coordinator/overrides.log; report them.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ready="$here/../scripts/ready.sh"
input=$(cat)
# Claude Code and Codex send a string; an argv array is joined so the parser still sees `gh pr merge`.
command=$(jq -r '.tool_input.command // empty | if type == "array" then join(" ") else . end' <<<"$input" 2>/dev/null)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd=$PWD
[ -n "$command" ] || exit 0

# One JSON object per merge found: {selector, repo, auto, override}, or {unparsed, override} for a merge whose flags the
# parser cannot place. Mirrors how gh parses its arguments closely enough to find the PR; anything it cannot place is
# resolved by `gh pr view` in the session's directory. The command is split into words and into commands by a
# quote-aware scan, so text inside a quoted argument (a --body) is never read as a command, an operator or an override.
# An override counts only as a leading assignment of the merge command itself (optionally after `env`).
targets=$(jq -rn --arg cmd "$command" --arg host "${GH_HOST:-github.com}" '
  def unq: gsub("\"(?<a>(?:[^\"\\\\]|\\\\.)*)\"|\u0027(?<b>[^\u0027]*)\u0027|\\\\(?<c>.)"; "\(.a // "")\(.b // "")\(.c // "")");
  def isop: . == "&&" or . == "||" or . == ";" or . == "&" or . == "|" or . == "\n";
  def isflag: startswith("-");
  # gh flags that may sit between `gh`, `pr` and `merge`; anything else there is unknown and fails closed.
  def skip($t):
    if .i >= ($t | length) then .
    elif $t[.i] == "-R" or $t[.i] == "--repo" then .repo = $t[.i + 1] | .i += 2 | skip($t)
    elif ($t[.i] | startswith("--repo=")) then .repo = $t[.i][7:] | .i += 1 | skip($t)
    elif ($t[.i] | startswith("-R=")) then .repo = $t[.i][3:] | .i += 1 | skip($t)
    elif ($t[.i] | test("^-R.")) then .repo = $t[.i][2:] | .i += 1 | skip($t)
    elif $t[.i] == "--hostname" then .host = $t[.i + 1] | .i += 2 | skip($t)
    elif ($t[.i] | startswith("--hostname=")) then .host = $t[.i][11:] | .i += 1 | skip($t)
    else . end;
  # First index after $from holding $word with only flags (and flag values) in between.
  def loose($t; $from; $word):
    if $from == null then null else
      [ range($from + 1; $t | length) | select($t[.] == $word) | . as $k
        | select(all(range($from + 1; $k); ($t[.] | isflag) or ($t[. - 1] | isflag))) ][0] end;
  def isassign: test("^[A-Za-z_][A-Za-z0-9_]*=");
  # $t: words with subshell and substitution marks removed (for parsing); $u: words only unquoted (for the reason).
  # The command word of a command: {i, ov} after leading assignments, `env` and env options, or null when env has an
  # option this does not know (-S/--split-string included). ov is the last COORD_READY_OVERRIDE reason in that prefix.
  def cmdat($t; $u):
    if .i >= ($t | length) then null else $t[.i] as $w
    | if .opts then
        if $w == "--" then .opts = false | .i += 1 | cmdat($t; $u)
        elif $w == "-i" or $w == "--ignore-environment" or $w == "-" or ($w | test("^--(unset|chdir)=|^-[uC].")) then
          .i += 1 | cmdat($t; $u)
        elif $w == "-u" or $w == "-C" or $w == "--unset" or $w == "--chdir" then .i += 2 | cmdat($t; $u)
        elif ($w | startswith("-")) then null
        else .opts = false | cmdat($t; $u) end
      elif $w == "" then .i += 1 | cmdat($t; $u)
      elif ($w | isassign) then
        (if ($u[.i] | startswith("COORD_READY_OVERRIDE=")) and ($u[.i] | length) > 21 then .ov = $u[.i][21:] else . end)
        | .i += 1 | cmdat($t; $u)
      elif $w == "env" then .opts = true | .i += 1 | cmdat($t; $u)
      else {i: .i, ov: .ov} end
    end;
  # An override counts only when it is a leading assignment of the command whose command word is $gi.
  def override($t; $u; $gi):
    ({i: 0, opts: false, ov: null} | cmdat($t; $u)) as $c
    | if $c != null and $c.i == $gi then $c.ov else null end;
  $cmd | gsub("\\\\\n"; " ")
  | [ scan("(?:\"(?:[^\"\\\\]|\\\\.)*\"|\u0027[^\u0027]*\u0027|\\\\.|[^\\s;&|])+|&&|\\|\\||[;&|\n]") ]
  | reduce .[] as $w ([[]]; if ($w | isop) then . + [[]] else .[-1] += [$w] end)
  | .[] | select(length > 0)
  | . as $raw | map(unq) as $u | ($raw | join(" ")) as $seg
  # `(gh`, `$(gh`, `` `gh `` and `5)` read as gh and 5, so a merge in a subshell or a substitution is still checked.
  | ($u | map(sub("^(\\$\\(|[(`{])+"; "") | sub("[)`}]+$"; ""))) as $t
  | [ range(0; $t | length) | select($t[.] | test("(^|/)gh$")) ] as $ghs
  | ([ $ghs[] as $gi | ({i: ($gi + 1), repo: null, host: null} | skip($t)) as $g
       | select($t[$g.i] == "pr") | ($g | .i += 1 | skip($t)) as $p
       | select($t[$p.i] == "merge")
       | {gi: $gi, a: $t[$p.i + 1:], repo: ($p.repo // $g.repo), host: ($p.host // $g.host)} ][0]) as $m
  | if $m != null then
      $m.a as $a
      | if ($a | index("--disable-auto")) != null then empty else
          (reduce range(0; $a | length) as $i ({skip: false, repo: $m.repo, sel: null};
             if .skip then .skip = false
             elif $a[$i] == "-R" or $a[$i] == "--repo" then .repo = $a[$i + 1] | .skip = true
             elif ($a[$i] | startswith("--repo=")) then .repo = $a[$i][7:]
             elif ($a[$i] | test("^-(b|t|F|-body|-subject|-body-file|-match-head-commit|-author-email)$")) then .skip = true
             elif ($a[$i] | startswith("-") | not) and .sel == null then .sel = $a[$i]
             else . end))
          | (if .repo != null and $m.host != null and (.repo | split("/") | length) == 2 then "\($m.host)/\(.repo)"
             else .repo end) as $repo
          | {selector: .sel, repo: $repo, auto: (($a | index("--auto")) != null), override: override($t; $u; $m.gi)} | @json
        end
    elif ([ $ghs[] | select($t[. + 1] == "api") ] | length) > 0
         and ($seg | test("repos/[^/\\s\"\u0027]+/[^/\\s\"\u0027]+/pulls/[0-9]+/merge\\b")) then
      ($seg | capture("repos/(?<o>[^/\\s\"\u0027]+)/(?<r>[^/\\s\"\u0027]+)/pulls/(?<n>[0-9]+)/merge")) as $m
      | (([ $seg | capture("--hostname[ =](?<h>[^\\s\"\u0027]+)") | .h ][0]) // $host) as $h
      | {selector: "https://\($h)/\($m.o)/\($m.r)/pull/\($m.n)", repo: null, auto: false,
         override: override($t; $u; [ $ghs[] | select($t[. + 1] == "api") ][0])} | @json
    else
      [ $ghs[] as $gi | loose($t; $gi; "pr") as $pj | loose($t; $pj; "merge") as $mk
        | select($mk != null and (($t[$mk + 1:] | index("--disable-auto")) == null)) | $gi ][0] as $gi
      # A command word that is a variable or a substitution ($GH, "$(cmd)") could be gh: pr ... merge after it fails closed.
      | (({i: 0, opts: false, ov: null} | cmdat($t; $u) | .i)
         // ([ range(0; $t | length) | select($t[.] != "" and $t[.] != "env" and ($t[.] | isassign | not)) ][0])) as $w0
      | (if $gi == null and $w0 != null and ($raw[$w0] | test("[$`]")) and (loose($t; loose($t; $w0; "pr"); "merge") as $mk
             | $mk != null and (($t[$mk + 1:] | index("--disable-auto")) == null)) then $w0 else $gi end) as $gi
      | if $gi == null then empty else {unparsed: true, override: override($t; $u; $gi)} | @json end
    end' 2>/dev/null) || targets=""
if [ -z "$targets" ]; then
  # Fail closed on a merge the parser did not find: gh, flags, pr, flags, merge anywhere in the text (for example
  # inside `bash -c "..."`, or split by a newline), or a REST merge path. A plain mention such as `gh pr list --search merge` does not match.
  fl='([[:space:]]+-[^[:space:]]*([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'
  if grep -qE "(^|[^[:alnum:]_.-])gh${fl}[[:space:]]+pr${fl}[[:space:]]+merge([^[:alnum:]_-]|\$)|pulls/[0-9]+/merge" < <(tr '\n' ' ' <<<"$command") \
     && ! grep -q -- '--disable-auto' <<<"$command"; then
    echo "[merge gate] Could not parse which PR this command merges; use \`gh pr merge <PR URL>\` without extra gh flags." >&2; exit 2
  fi
  exit 0
fi

log_override() {
  local root
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
  mkdir -p "$root/.coordinator" 2>/dev/null && { [ -f "$root/.coordinator/.gitignore" ] || printf '*\n' > "$root/.coordinator/.gitignore"; }
  printf '%s\toverride\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$(tr '\n' ' ' <<<"$command" | head -c 300)" \
    >> "$root/.coordinator/overrides.log" 2>/dev/null \
    || echo "[merge gate] warning: could not write $root/.coordinator/overrides.log" >&2
  echo "[merge gate] override accepted: $1 (logged; include it in the next report)" >&2
}

fails=""
while IFS= read -r t; do
  [ -n "$t" ] || continue
  reason=$(jq -r '.override // empty' <<<"$t")
  if [ -n "$reason" ]; then log_override "$reason"; continue; fi
  if [ "$(jq -r '.unparsed // false' <<<"$t")" = "true" ]; then
    fails+="could not parse which PR \"$(head -c 120 <<<"$command")\" merges; use \`gh pr merge <PR URL>\` without extra gh flags"$'\n'
    continue
  fi
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
