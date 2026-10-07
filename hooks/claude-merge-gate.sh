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
# Only a leading assignment of a top-level merge counts (`env` and its -i/-u/-C/-- options may come first); the same
# text inside an argument does not. A nested merge ($(...), backticks, a subshell, bash -c) always blocks, override or not.
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

# The gate checks a merge only when it is a top-level simple command: `gh [flags] pr [flags] merge ...` or
# `gh api ... pulls/N/merge`, after ; && || | & or a newline, optionally after assignments and `env`. A quote-aware
# scan splits the command into words and commands, and drops `#` comments, redirections and backslash-newlines as bash
# does. The jq program prints one line per command: bad, a tab, t, a tab, the command text. t is the merge as JSON
# {selector, repo, auto, disabled, override}, or null. bad is true for a merge the gate cannot place: inside $(...), backticks, ( ), { },
# bash -c, eval or xargs; after a variable as the command; or with an unknown gh flag. Every bad form blocks.
segs=$(jq -rn --arg cmd "$command" --arg host "${GH_HOST:-github.com}" '
  def unq: gsub("\"(?<a>(?:[^\"\\\\]|\\\\.)*)\"|\u0027(?<b>[^\u0027]*)\u0027|\\\\(?<c>.)"; "\(.a // "")\(.b // "")\(.c // "")");
  def isop: . == "&&" or . == "||" or . == ";" or . == "&" or . == "|" or . == "\n";
  def isflag: startswith("-");
  def isredir: test("^[0-9]*(&>>?|<<<|<<-?|>>|>\\||<>|[<>]&([0-9]+-?|-)?|[<>])$");
  # Drop each redirection and, unless it duplicates a descriptor (2>&1), the file word after it.
  def noredir:
    reduce .[] as $w ({out: [], skip: false};
      if .skip then .skip = false
      elif ($w | isredir) then (if ($w | test("[<>]&([0-9]+-?|-)$")) then . else .skip = true end)
      else .out += [$w] end) | .out;
  # gh flags that may sit between `gh`, `pr` and `merge`.
  def skip($t):
    if .i >= ($t | length) then .
    elif $t[.i] == "-R" or $t[.i] == "--repo" then .repo = $t[.i + 1] | .i += 2 | skip($t)
    elif ($t[.i] | startswith("--repo=")) then .repo = $t[.i][7:] | .i += 1 | skip($t)
    elif ($t[.i] | test("^-R.")) then .repo = ($t[.i][2:] | ltrimstr("=")) | .i += 1 | skip($t)
    elif $t[.i] == "--hostname" then .host = $t[.i + 1] | .i += 2 | skip($t)
    elif ($t[.i] | startswith("--hostname=")) then .host = $t[.i][11:] | .i += 1 | skip($t)
    else . end;
  # True when `pr` and later `merge` appear with only flags (and flag values) between them. Grouping marks are
  # removed first, so `$(gh pr merge 5)`, `(gh pr`, `$GH pr merge` and `echo gh pr merge` all match. One pass.
  def prmerge:
    map(sub("^(\\$\\(|[(`{])+"; "") | sub("[)`}]+$"; "")) as $t
    | def walk($k; $seen):
        if $k >= ($t | length) then false
        elif $seen and $t[$k] == "merge" then true
        elif $t[$k] == "pr" then walk($k + 1; true)
        elif $seen and (($t[$k] | isflag) or ($t[$k - 1] | isflag)) then walk($k + 1; true)
        else walk($k + 1; false) end;
      walk(0; false);
  # The merge arguments: the selector, -R, and --auto / --disable-auto only as flags, never as the value of a flag.
  def margs($a; $repo):
    reduce range(0; $a | length) as $i ({skip: false, repo: $repo, sel: null, auto: false, dis: false};
      if .skip then .skip = false
      elif $a[$i] == "-R" or $a[$i] == "--repo" then .repo = $a[$i + 1] | .skip = true
      elif ($a[$i] | startswith("--repo=")) then .repo = $a[$i][7:]
      elif ($a[$i] | test("^-R.")) then .repo = ($a[$i][2:] | ltrimstr("="))
      elif $a[$i] == "--auto" then .auto = true
      elif $a[$i] == "--disable-auto" then .dis = true
      elif ($a[$i] | test("^-(b|t|F|A|-body|-subject|-body-file|-match-head-commit|-author-email)$")) then .skip = true
      elif ($a[$i] | startswith("-") | not) and .sel == null then .sel = $a[$i]
      else . end);
  def isassign: test("^[A-Za-z_][A-Za-z0-9_]*=");
  # The command word: {i, ov, repo, host} after leading assignments, `env` and env options, or null when env has an
  # option this does not know (-S/--split-string included). The last COORD_READY_OVERRIDE, GH_REPO and GH_HOST win.
  def cmdat($t):
    if .i >= ($t | length) then null else $t[.i] as $w
    | if .opts then
        if $w == "--" then .opts = false | .i += 1 | cmdat($t)
        elif $w == "-i" or $w == "--ignore-environment" or $w == "-" or ($w | test("^--(unset|chdir)=|^-[uC].")) then
          .i += 1 | cmdat($t)
        elif $w == "-u" or $w == "-C" or $w == "--unset" or $w == "--chdir" then .i += 2 | cmdat($t)
        elif ($w | startswith("-")) then null
        else .opts = false | cmdat($t) end
      elif ($w | isassign) then
        ($w | capture("^(?<k>[^=]*)=(?<v>.*)$"; "s")) as $kv
        | (if ($kv.k | IN("COORD_READY_OVERRIDE", "GH_REPO", "GH_HOST")) then .[$kv.k] = $kv.v else . end)
        | .i += 1 | cmdat($t)
      elif $w == "env" then .opts = true | .i += 1 | cmdat($t)
      else {i: .i, ov: .COORD_READY_OVERRIDE, repo: .GH_REPO, host: .GH_HOST} end
    end;
  $cmd | gsub("\\\\\n"; "")
  | [ scan("\\(*#[^\n]*|[0-9]*(?:&>>?|<<<|<<-?|>>|>\\||<>|[<>]&(?:[0-9]+-?|-)?|[<>])|(?:\"(?:[^\"\\\\]|\\\\.)*\"|\u0027[^\u0027]*\u0027|\\\\.|[^\\s;&|<>])+|&&|\\|\\||[;&|\n]") ]
  | map(select(test("^\\(*#") | not))
  | reduce .[] as $w ([[]]; if ($w | isop) then . + [[]] else .[-1] += [$w] end)
  | [ .[] | select(length > 0) ] | . as $all
  | (first(range(0; $all | length) | select($all[.][0] | unq | IN("cd", "pushd", "popd"))) // infinite) as $cdk
  | range(0; $all | length) as $k | $all[$k] | ($cdk < $k) as $cd
  | (join(" ") | gsub("[\n\t]"; " ")) as $seg | noredir | . as $raw | map(unq) as $u
  | ({i: 0, opts: false} | cmdat($u)) as $c
  # The command word must be a plain, unquoted gh (or a path to it): no `$(`, `(`, quote or escape around it.
  | (if $c != null and $raw[$c.i] == $u[$c.i] and ($u[$c.i] | test("^([A-Za-z0-9_.~+-]*/)*gh$")) then $c.i else null end) as $gi
  | (if $gi == null then null else {i: ($gi + 1), repo: null, host: null} | skip($u) end) as $g
  | (if $g != null and $u[$g.i] == "pr" then ($g | .i += 1 | skip($u)) else null end) as $p
  | if $p != null and $u[$p.i] == "merge" then
      margs($u[$p.i + 1:]; $p.repo // $g.repo // $c.repo)
      | {seg: $seg, bad: ($raw[$p.i + 1:] | prmerge), t: {selector: .sel, repo: .repo, host: ($p.host // $g.host // $c.host),
         auto: .auto, disabled: .dis, override: $c.ov, cd: $cd}}
    elif $gi != null and $u[$gi + 1] == "api" and ($seg | test("repos/[^/\\s\"\u0027]+/[^/\\s\"\u0027]+/pulls/[0-9]+/merge\\b")) then
      ($seg | capture("repos/(?<o>[^/\\s\"\u0027]+)/(?<r>[^/\\s\"\u0027]+)/pulls/(?<n>[0-9]+)/merge")) as $m
      | (([ $seg | capture("--hostname[ =](?<h>[^\\s\"\u0027]+)") | .h ][0]) // $c.host // $host) as $h
      # With no -X/--method and no field flags, gh api sends a GET (an is-it-merged check), so no READY is needed.
      | ($u | join(" ")) as $a | "(^| )(-X ?|--method[ =])" as $mf
      | {seg: $seg, bad: ($raw | prmerge), t: {selector: "https://\($h)/\($m.o)/\($m.r)/pull/\($m.n)", auto: false, override: $c.ov,
         disabled: ($a | test($mf + "(GET|HEAD)( |$)"; "i") or (test($mf) or test("(^| )(-[fF]|--field|--raw-field|--input)")) == false)}}
    else {seg: $seg, bad: ($raw | prmerge), t: null} end
  | "\(.bad)\t\(.t | tojson)\t\(.seg)"' 2>/dev/null) || segs=""
# If jq fails, any command that names a merge blocks.
[ -z "$segs" ] && [[ "$command" == *merge* ]] && segs=$'true\tnull\t-'

# mentions() counts gh .. pr .. merge and REST merge paths in raw text, quoted text included. Only a top-level merge
# may hold one, and the whole command may hold no more than its commands, so `bash -c "gh pr merge 5"` blocks.
fl='([[:space:]]+-[^[:space:]]*([[:space:]]+[^-[:space:]][^[:space:]]*)?)*'
mentions() {
  local s=${1//$'\\\n'/}
  tr '\n' ' ' <<<"$s" | grep -oE "(^|[^[:alnum:]_.-])gh${fl}[[:space:]]+pr${fl}[[:space:]]+merge[[:alnum:]_-]*|pulls/[0-9]+/merge[[:alnum:]_-]*" \
    | grep -cE 'merge$' || true
}
nested=false; sum=0; targets=""
while IFS=$'\t' read -r bad t seg; do
  [ -n "$bad" ] || continue
  m=0; [[ "$seg" == *merge* ]] && m=$(mentions "$seg"); sum=$((sum + m))
  if [ "$t" != null ]; then targets+="$t"$'\n'; allow=1; else allow=0; fi
  { [ "$bad" = true ] || [ "$m" -gt "$allow" ]; } && nested=true
done <<<"$segs"
if [ "$nested" = true ] || [ "$(mentions "$command")" -gt "$sum" ]; then
  { echo "[merge gate] Blocked: run \`gh pr merge\` as its own top-level command so READY can check it."
    echo "A merge the gate cannot place (nested, after a variable, an unknown gh flag, merge text in an argument) never takes an override."
    echo "If this command does not merge, keep the words gh … pr … merge out of it: put the text in a file (-F / --body-file) or search for 'pr merg[e]'."
  } >&2; exit 2
fi
[ -n "$targets" ] || exit 0

log_override() {
  local root
  root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "$cwd")
  mkdir -p "$root/.coordinator" 2>/dev/null && { [ -f "$root/.coordinator/.gitignore" ] || printf '*\n' > "$root/.coordinator/.gitignore"; }
  printf '%s\toverride\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$(tr '\n' ' ' <<<"$command" | head -c 300)" \
    >> "$root/.coordinator/overrides.log" 2>/dev/null \
    || echo "[merge gate] warning: could not write $root/.coordinator/overrides.log" >&2
  echo "[merge gate] override accepted: $1 (logged; include it in the next report)" >&2
}

fails=""; reasons=()
while IFS= read -r t; do
  [ -n "$t" ] || continue
  IFS=$'\x1f' read -r reason dis sel repo auto host cd \
    < <(jq -r '[.override, .disabled, .selector, .repo, .auto, .host, .cd] | map(. // "" | tostring) | join("\u001f")' <<<"$t")
  if [ -n "$reason" ]; then reasons+=("$reason"); continue; fi
  [ "$dis" = true ] && continue
  if [[ "$sel" =~ ^https?://[^/]+/[^/]+/[^/]+/pull/[0-9]+ ]] || [[ "$sel" =~ ^([^/[:space:]]+/)?[^/#[:space:]]+/[^/#[:space:]]+#[0-9]+$ ]]; then
    url="$sel"
  elif [ "$cd" = true ] && [ -z "$repo" ]; then  # an earlier cd/pushd changes where a number or branch resolves
    fails+="a cd or pushd earlier in this command changes the directory; merge with the full PR URL"$'\n'; continue
  else
    args=(pr view); [ -n "$sel" ] && args+=("$sel"); [ -n "$repo" ] && args+=(-R "$repo")
    url=$(cd "$cwd" && env ${host:+GH_HOST="$host"} gh "${args[@]}" --json url -q .url 2>/dev/null) || url=""
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

# Overrides are logged only when nothing in the command blocks.
[ -z "$fails" ] && { for r in ${reasons[@]+"${reasons[@]}"}; do log_override "$r"; done; exit 0; }
{
  echo "[merge gate] Merge blocked; the READY fence is not met."
  printf '%s' "$fails"
  echo 'Fix the blockers and retry. If a blocker is verifiably wrong (for example a stale or misread check), re-run with COORD_READY_OVERRIDE="<reason>" prefixed to the command; overrides are logged and must be reported.'
} >&2
exit 2
