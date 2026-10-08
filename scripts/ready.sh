#!/usr/bin/env bash
# READY fence check for execution-coordinator. Read-only; REST only (works when the GraphQL budget is spent,
# except the owed-reply audit, which fails closed).
#   ready.sh <pr-url|owner/repo#N> [--sha S] [--paths "a/**,b/*.ts"] [--base-sha S] [--key K] [--allow-pending] [--json]
# Host comes from the URL, else $GH_HOST, else github.com.
# BLOCK: not open or draft; head is not --sha; conflicts, behind, unknown or blocked mergeability; a required check
#   failing, missing or pending (pending allowed with --allow-pending); a latest review requesting changes; owed
#   replies or unsent drafts (scripts/pr-threads.sh); files outside the --paths globs (** any depth, * one segment).
# WARN: failing non-required checks; unreadable required-check list (then every check counts as required); deleted
#   tests; changed CI, test or lint config; head not descending from --base-sha.
# --key K reads pr, paths and base_sha from dispatch K in <git root>/.coordinator/status.json (scripts/status.sh)
#   and records the verdict there with the key, PR, head, paths, --allow-pending and run_id it covered, which
#   `status.sh dispatch K --state accepted` requires. It first records ok=false ("in progress") with a token for
#   this run, so a run that stops early never leaves an old pass. The final verdict lands only while that token is
#   still stored; a later run, or a pr, paths or run_id change, replaces it. Every exit 3 with --key, usage errors
#   included, records ok=false, unless the lock cannot be taken. An accepted dispatch keeps its verdict, and so
#   does a merged PR whose head is the stored verdict's head. Writes hold .coordinator/.lock (COORD_LOCK_TRIES).
# Output: "READY|NOT READY <url> @ <sha9>", then "  BLOCK ..." and "  WARN ..." lines. Exit 0 READY, 1 NOT READY,
# 3 unreadable (never treat 3 as READY). A PR, check, review or file read that cannot be parsed is unreadable.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
# Lock: mkdir is atomic (no flock on macOS). A write holds it for milliseconds, so a lock that outlasts
# COORD_LOCK_TRIES tries of 0.1s (default 100; 0 means one try) is held by a slow writer or left by a stopped process.
# Keep these lines the same in status.sh and ready.sh.
locked="" tmp="" rtmp=""
lock() {
  local i=0; [ -w "$dir" ] || { echo "${0##*/}: cannot lock: $dir is not writable" >&2; return 1; }
  until mkdir "$dir/.lock" 2>/dev/null; do
    i=$((i + 1)); [ "$i" -lt "${COORD_LOCK_TRIES:-100}" ] || { echo "${0##*/}: .coordinator/.lock is still held (a stopped process may have left it); if no status.sh or ready.sh is running, remove it (rm -r .coordinator/.lock) and retry" >&2; return 1; }
    sleep 0.1
  done; locked=1
}
unlock() { [ -z "$locked" ] || rm -rf "$dir/.lock"; locked=""; }
trap '[ -z "$tmp" ] || rm -rf "$tmp"; [ -z "$rtmp" ] || rm -f "$rtmp"; unlock' EXIT; trap 'exit 130' INT; trap 'exit 143' TERM
tok="$$.$RANDOM$RANDOM.$(date +%s)"  # this run's token on the dispatch verdict
# record VERDICT_JSON [own]: store the verdict and this run's token on dispatch $key, under the lock. With "own" it
# writes only while the stored token is this run's. An accepted or missing dispatch is left alone. Sets the
# dispatch PR only when it has none.
record() {
  [ -n "${sfile:-}" ] && [ -n "${d:-}" ] || return 0
  lock || return 1
  rtmp=$(mktemp "$dir/.status.XXXXXX") || { rtmp=""; unlock; return 1; }  # exclusive and unpredictable: never follow a planted symlink
  local rc=0; jq --arg k "$key" --arg tok "$tok" --arg own "${2:-}" --argjson v "$1" '
       .dispatches[$k] as $d
       | if $d == null or $d.state == "accepted" or ($own != "" and $d.ready.token != $tok) then .
         else (if $v.pr then .dispatches[$k].pr //= $v.pr else . end) | .dispatches[$k].ready = ($v + {key: $k, token: $tok}) end' \
       "$sfile" > "$rtmp" && mv "$rtmp" "$sfile" || rc=1
  rm -f "$rtmp"; rtmp=""; unlock; return "$rc"
}
# Exit 3. With --key, the dispatch's verdict becomes ok=false, so an old pass never survives it.
fail3() {
  record "$(jq -cn --arg why "$*" --arg t "$(now)" '{ok: false, unreadable: true, at: $t, blockers: ["unreadable: \($why)"]}')"
  exit 3
}
unreadable() { echo "UNREADABLE ${ref:-?}: $*" >&2; fail3 "$*"; }
usage() { echo "ready.sh: $*" >&2; fail3 "$*"; }
need() { [ "$1" -ge 2 ] || usage "$2 needs a value"; }

# Find --key before the full parse, so a usage error below still clears that dispatch's verdict.
ref="" sha="" paths="" base_sha="" key="" allow_pending=0 json=0 sfile="" dir="" d="" run="" prior=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in -h|--help) sed -n '2,/^set /p' "$0" | grep '^#'; exit 0;; esac
  if [ "${args[i]}" = "--key" ] && [ $((i + 1)) -lt ${#args[@]} ]; then key="${args[i + 1]}"; break; fi
done
if [ -n "$key" ]; then
  root=$(git rev-parse --show-toplevel 2>/dev/null) || unreadable "--key needs to run inside the coordinated git repository"
  dir="$root/.coordinator"; sfile="$dir/status.json"
  d=$(jq -c --arg k "$key" '.dispatches[$k] // empty' "$sfile" 2>/dev/null)
  [ -n "$d" ] || unreadable "no dispatch \"$key\" in $sfile"
  [ "$(jq -r .state <<<"$d")" != "accepted" ] || echo "ready.sh: dispatch \"$key\" is accepted; its verdict is kept" >&2
  prior=$(jq -c '.ready // empty' <<<"$d")
  record "$(jq -cn --arg t "$(now)" '{ok: false, in_progress: true, at: $t, blockers: ["READY check in progress"]}')" \
    || unreadable "could not mark the READY check in progress in $sfile"
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --sha) need $# "$1"; sha="$2"; shift 2;;
    --paths) need $# "$1"; paths="$2"; shift 2;;
    --base-sha) need $# "$1"; base_sha="$2"; shift 2;;
    --key) need $# "$1"; shift 2;;
    --allow-pending) allow_pending=1; shift;;
    --json) json=1; shift;;
    -*) usage "unknown flag $1";;
    *) ref="$1"; shift;;
  esac
done

if [ -n "$key" ]; then
  [ -n "$ref" ] || ref=$(jq -r '.pr // empty' <<<"$d")
  [ -n "$paths" ] || paths=$(jq -r '(.paths // []) | join(",")' <<<"$d")
  [ -n "$base_sha" ] || base_sha=$(jq -r '.base_sha // empty' <<<"$d")
  run=$(jq -r '.run_id // empty' <<<"$d")
fi

host="${GH_HOST:-github.com}"
if [[ "$ref" =~ ^https?://([^/]+)/([^/]+)/([^/]+)/pull/([0-9]+) ]]; then
  host="${BASH_REMATCH[1]}"; owner="${BASH_REMATCH[2]}"; repo="${BASH_REMATCH[3]}"; num="${BASH_REMATCH[4]}"
elif [[ "$ref" =~ ^(([^/[:space:]]+\.[^/[:space:]]+)/)?([^/#[:space:]]+)/([^/#[:space:]]+)#([0-9]+)$ ]]; then
  [ -n "${BASH_REMATCH[2]}" ] && host="${BASH_REMATCH[2]}"
  owner="${BASH_REMATCH[3]}"; repo="${BASH_REMATCH[4]}"; num="${BASH_REMATCH[5]}"
else
  unreadable "expected a PR URL or owner/repo#N"
fi
R="repos/$owner/$repo"
url="https://$host/$owner/$repo/pull/$num"
tmp=$(mktemp -d)
api() { gh api --hostname "$host" "$@"; }

api "$R/pulls/$num" > "$tmp/pr" 2> "$tmp/err" || unreadable "$(head -c 300 "$tmp/err")"
# GitHub computes mergeability lazily; the first read after a push can be null.
if [ "$(jq -r '.state == "open" and .mergeable == null' "$tmp/pr")" = "true" ]; then
  sleep 3; api "$R/pulls/$num" > "$tmp/pr" 2> "$tmp/err" || unreadable "$(head -c 300 "$tmp/err")"
fi
jq -e 'type == "object" and (.head.sha | type) == "string" and (.head.sha | test("^[0-9a-f]{40}$"))' "$tmp/pr" \
  >/dev/null 2>&1 || unreadable "the PR read is not pull request JSON with a head SHA"
head=$(jq -r '.head.sha' "$tmp/pr"); base=$(jq -r '.base.ref' "$tmp/pr")
base_enc=$(jq -rn --arg b "$base" '$b|@uri')

# Verdict lines: "B <text>" blocks, "W <text>" warns.
jq -r --arg sha "$sha" '
  (if .state != "open" then "B PR is \(if .merged then "merged" else .state end)" else empty end),
  (if .draft then "B PR is a draft" else empty end),
  (if $sha != "" and (.head.sha | startswith($sha) | not) then "B reported SHA \($sha[0:9]) is not the PR head \(.head.sha[0:9]) (the READY claim is stale)" else empty end),
  (.mergeable_state as $ms
   | if .mergeable == false or $ms == "dirty" then "B merge conflicts with base"
     elif $ms == "behind" then "B branch is behind base and the repo requires it up to date"
     elif $ms == "unknown" or .mergeable == null then "B GitHub has not computed mergeability yet (re-run in a minute)"
     elif $ms == "blocked" then "B branch protection blocks the merge (required reviews or required checks)"
     elif $ms == "unstable" then "W non-required checks are failing (mergeable_state unstable)"
     else empty end)' "$tmp/pr" > "$tmp/v" || unreadable "could not evaluate the PR state"

# Required checks: classic branch protection, then rulesets. Unreadable -> null -> every check counts as required.
classic=$(api "$R/branches/$base_enc/protection/required_status_checks" --jq '[(.contexts // [])[], ((.checks // [])[] | .context)]' 2>/dev/null) || classic=null
rules=$(api "$R/rules/branches/$base_enc" --paginate --jq '.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[]?.context' 2>/dev/null) || rules=""
required=$(jq -cn --argjson c "${classic:-null}" --arg r "$rules" '
  ($r | split("\n") | map(select(. != ""))) as $rr
  | if $c == null and ($rr | length) == 0 then null else (($c // []) + $rr | unique) end')

api "$R/commits/$head/check-runs?per_page=100" --paginate \
  --jq '.check_runs[] | {name, status, conclusion, started_at, html_url}' > "$tmp/runs" 2> "$tmp/err" \
  || unreadable "check runs: $(head -c 300 "$tmp/err")"
api "$R/commits/$head/status" --jq '.statuses[] | {context, state, target_url}' > "$tmp/sts" 2>/dev/null || : > "$tmp/sts"
jq -rn --slurpfile runs "$tmp/runs" --slurpfile sts "$tmp/sts" --argjson req "$required" \
      --argjson ap "$allow_pending" --arg h9 "${head:0:9}" '
  def isreq($n): $req == null or ($req | index($n)) != null;
  ( ($runs | group_by(.name) | map(max_by(.started_at // ""))
      | map({name, url: .html_url, state: (if .status != "completed" then "pending"
               elif (.conclusion | IN("success", "neutral", "skipped")) then "pass" else "fail" end)}))
    + ($sts | map({name: .context, url: .target_url,
               state: (if .state == "success" then "pass" elif .state == "pending" then "pending" else "fail" end)}))
  ) as $checks
  | ( ($req // [])[] | select(. as $n | ($checks | map(.name) | index($n)) == null)
      | "B required check \"\(.)\" has not reported on \($h9)" ),
    ( $checks[]
      | if .state == "fail" then (if isreq(.name) then "B" else "W" end) + " check failed: \(.name)\(if .url then " (\(.url))" else "" end)"
        elif .state == "pending" and isreq(.name) and $ap == 0 then "B check pending: \(.name)"
        else empty end ),
    ( if $req == null then "W required-check list unreadable; treated every check as required" else empty end )' >> "$tmp/v" \
  || unreadable "could not evaluate the checks"

# Reviews: anyone whose latest non-comment review still requests changes. Unreadable reviews fail closed.
api "$R/pulls/$num/reviews?per_page=100" --paginate --jq '.[] | {state, login: .user.login}' > "$tmp/rev" 2> "$tmp/err" \
  || unreadable "reviews: $(head -c 300 "$tmp/err")"
jq -rs 'reduce .[] as $r ({}; if ($r.state | IN("COMMENTED", "PENDING")) then . else .[$r.login // "ghost"] = $r.state end)
        | to_entries[] | select(.value == "CHANGES_REQUESTED") | "B changes requested by \(.key)"' "$tmp/rev" >> "$tmp/v" \
  || unreadable "could not evaluate the reviews"

# Owed replies and unsent drafts. Exit 3 from the audit fails closed.
threads=$("$here/pr-threads.sh" "$url" 2>&1); trc=$?
owed=$(grep -E '^(ACTION|UNSENT)' <<<"$threads" | sed -E 's/^(ACTION|UNSENT) +/B reply owed: \1 /')
if [ "$trc" -eq 0 ] || [ "$trc" -eq 1 ]; then
  [ -n "$owed" ] && echo "$owed" >> "$tmp/v"
  [ "$trc" -eq 1 ] && [ -z "$owed" ] && echo "B pr-threads.sh reported actionable feedback" >> "$tmp/v"
else
  echo "B could not read owed replies (pr-threads.sh exit $trc); fail closed" >> "$tmp/v"
fi

# Scope and tamper flags from the PR file list.
api "$R/pulls/$num/files?per_page=100" --paginate --jq '.[] | {filename, status}' > "$tmp/files" 2> "$tmp/err" \
  || unreadable "file list: $(head -c 300 "$tmp/err")"
jq -rs --arg globs "$paths" '
  def globre: . as $g
    | gsub("(?<c>[.+^${}()|\\[\\]\\\\])"; "\\\(.c)")
    | gsub("\\*\\*/"; "\u0001") | gsub("\\*\\*"; "\u0002") | gsub("\\*"; "[^/]*") | gsub("\\?"; "[^/]")
    | gsub("\u0001"; "(?:.*/)?") | gsub("\u0002"; ".*")
    | "^" + . + (if ($g | endswith("/")) then ".*" else "" end) + "$";
  ($globs | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""))) as $g
  | ($g | map(globre)) as $res
  | (if ($g | length) > 0 then
       [ .[].filename | select(. as $f | any($res[]; . as $re | $f | test($re)) | not) ] as $out
       | if ($out | length) > 0 then
           "B out-of-scope files (\($out | length)) vs brief paths [\($g | join(", "))]: \($out[0:15] | join(", "))\(if ($out | length) > 15 then " ..." else "" end)"
         else empty end
     else empty end),
    ([ .[] | select(.status == "removed" and (.filename | test("(^|/)(__tests__|tests?|spec|e2e)/|\\.(test|spec)\\.[cm]?[jt]sx?$|_test\\.(go|py)$|(^|/)test_[^/]+\\.py$"))) | .filename ]
     | if length > 0 then "W tests deleted: \(.[0:10] | join(", ")) (confirm each is intended, not a weakened gate)" else empty end),
    ([ .[] | .filename | select(test("^\\.github/(workflows/|CODEOWNERS)|(^|/)(jest|vitest|playwright|karma|babel)\\.config\\.|(^|/)(\\.eslintrc[^/]*|eslint\\.config\\.[^/]+|tsconfig[^/]*\\.json|codecov\\.ya?ml|\\.coveragerc|pytest\\.ini|setup\\.cfg|tox\\.ini|\\.golangci\\.ya?ml|ruff\\.toml)$")) ]
     | if length > 0 then "W CI/test/lint config changed: \(.[0:10] | join(", ")) (confirm no check was weakened)" else empty end)
' "$tmp/files" >> "$tmp/v" || unreadable "file list: could not check the scope (an entry without a filename?)"

if [ -n "$base_sha" ]; then
  if cmp=$(api "$R/compare/$base_sha...$head" --jq '.status' 2> "$tmp/err"); then
    case "$cmp" in diverged|behind)
      echo "W head ${head:0:9} does not descend from dispatch base ${base_sha:0:9} (history rewritten or wrong branch)" >> "$tmp/v";; esac
  else
    echo "W dispatch base ${base_sha:0:9} not comparable: $(head -c 200 "$tmp/err" | tr '\n' ' ')" >> "$tmp/v"
  fi
fi

result=$(jq -Rn --slurpfile pr "$tmp/pr" --arg url "$url" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  [inputs | select(. != "")] as $v
  | ($v | map(select(startswith("B ")) | .[2:])) as $b
  | { ok: ($b | length == 0), pr: $url, title: $pr[0].title, head: $pr[0].head.sha, base: $pr[0].base.ref,
      mergeable_state: $pr[0].mergeable_state, blockers: $b,
      warnings: ($v | map(select(startswith("W ")) | .[2:])), checked_at: $t }' < "$tmp/v")
ok=$(jq -r '.ok' <<<"$result" 2>/dev/null); [ "$ok" = "true" ] || [ "$ok" = "false" ] || unreadable "could not build the verdict"

# The verdict names what it covered: PR, head, --paths scope, --allow-pending and the dispatch run. A merged PR
# whose head is the stored verdict's head keeps that verdict.
verdict=$(jq -c --arg p "$paths" --argjson ap "$allow_pending" --arg run "$run" '
  {ok, pr, head, paths: ($p | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""))),
   allow_pending: ($ap == 1), run: (if $run == "" then null else $run end), at: .checked_at, blockers}' <<<"$result")
if [ -n "$prior" ] && [ "$(jq -r '.merged' "$tmp/pr")" = "true" ] && [ "$(jq -r '.head' <<<"$prior")" = "$head" ]; then
  verdict="$prior"; echo "ready.sh: the PR is merged at the head the stored verdict checked; that verdict is kept" >&2
fi
if [ -n "$key" ] && [ "$(jq -r .state <<<"$d")" != "accepted" ]; then
  record "$verdict" own || unreadable "could not record the verdict in $sfile"
  [ "$(jq -r --arg k "$key" '.dispatches[$k].ready.token' "$sfile")" = "$tok" ] \
    || echo "ready.sh: a later READY run or a pr, paths or run_id change replaced this run's record; this verdict was not recorded" >&2
fi

if [ "$json" -eq 1 ]; then
  echo "$result"
else
  jq -r '"\(if .ok then "READY" else "NOT READY" end) \(.pr) @ \(.head[0:9]) (\(.mergeable_state))",
         (.blockers[] | "  BLOCK \(.)"), (.warnings[] | "  WARN  \(.)")' <<<"$result"
fi
[ "$ok" = "true" ] && exit 0 || exit 1
