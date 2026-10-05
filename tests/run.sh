#!/usr/bin/env bash
# Coordinator eval suite: sandbox tests for the shipped scripts and hooks. Offline: `gh` is replaced by a stub that
# serves fixture JSON, so nothing touches GitHub. Runs in throwaway git repos with a throwaway $HOME.
#   tests/run.sh          exit 0 when every case passes, 1 otherwise
# Every lesson in SKILL.md §14 that a script can enforce gets a regression case here.
set -u

S=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
st="$S/scripts/status.sh"; ready="$S/scripts/ready.sh"; hook="$S/hooks/claude-stop-hook.sh"; gate="$S/hooks/claude-merge-gate.sh"
pass=0; fail=0
t() { if [ "$1" = "$2" ]; then echo "PASS $3"; pass=$((pass + 1)); else echo "FAIL $3 (got '$1', want '$2')"; fail=$((fail + 1)); fi; }
has() { if grep -qF -- "$2" <<<"$1"; then echo "PASS $3"; pass=$((pass + 1)); else echo "FAIL $3 (missing '$2' in: $1)"; fail=$((fail + 1)); fi; }
hasnt() { if grep -qF -- "$2" <<<"$1"; then echo "FAIL $3 (unexpected '$2')"; fail=$((fail + 1)); else echo "PASS $3"; pass=$((pass + 1)); fi; }

export HOME; HOME=$(mktemp -d)
R=$(mktemp -d); NR=$(mktemp -d); BIN=$(mktemp -d); export STUB_DIR; STUB_DIR=$(mktemp -d)
trap 'rm -rf "$HOME" "$R" "$NR" "$BIN" "$STUB_DIR"' EXIT
unset CLAUDE_CODE_SESSION_ID COORD_QUIET COORD_KEEPALIVE AGENT_SESSION_NAME GH_HOST
cd "$R" && git init -q && git -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
sj() { jq -r "$1" "$R/.coordinator/status.json"; }

# ---- gh stub -------------------------------------------------------------------------------------------------
cat > "$BIN/gh" <<'STUB'
#!/usr/bin/env bash
# Fixture-backed gh: `gh api <path>` and `gh pr view`. A missing fixture file means HTTP 404.
jqf=""; path=""; sub="$1"; shift
if [ "$sub" = "pr" ]; then
  [ "${STUB_PRVIEW:-0}" = "1" ] || { echo "no pull requests found" >&2; exit 1; }
  sel=""; [ "$2" != "--json" ] && [ -n "${2:-}" ] && sel="$2"
  echo "https://github.com/o/r/pull/${sel:-7}"; exit 0
fi
while [ $# -gt 0 ]; do
  case "$1" in
    --hostname|-X|-f|-F) shift 2;; --jq|-q) jqf="$2"; shift 2;; --paginate) shift;;
    -*) shift;; *) [ -z "$path" ] && path="$1"; shift;;
  esac
done
if [ "$path" = graphql ] && [ "${STUB_NO_GRAPHQL:-0}" = "1" ]; then
  echo '{"message":"GitHub GraphQL is not available from Claude Code sessions; use the REST API"}' >&2; exit 1
fi
case "$path" in
  graphql) f=graphql.json;;
  user) f=user.json;;
  */ccr/review_threads) f=threads.json;;
  */pulls/*/comments*) f=rcomments.json;;
  */issues/*/comments*) f=icomments.json;;
  */protection/required_status_checks) f=required.json;;
  */rules/branches/*) f=rules.json;;
  */check-runs*) f=runs.json;;
  */status) f=status.json;;
  */reviews*) f=reviews.json;;
  */files*) f=files.json;;
  */compare/*) f=compare.json;;
  */pulls/*) f=pr.json;;
  *) f=none;;
esac
[ -f "$STUB_DIR/$f" ] || { echo "gh: Not Found (HTTP 404) $path" >&2; exit 1; }
if [ -n "$jqf" ]; then jq -rc "$jqf" "$STUB_DIR/$f"; else cat "$STUB_DIR/$f"; fi
STUB
chmod +x "$BIN/gh"; export PATH="$BIN:$PATH"
H=abc1234567890abc1234567890abc1234567890a
fixtures() {
  rm -f "$STUB_DIR"/*.json
  jq -n --arg h "$H" '{state:"open", draft:false, merged:false, mergeable:true, mergeable_state:"clean", title:"t",
    html_url:"https://github.com/o/r/pull/7", head:{sha:$h}, base:{ref:"main"}}' > "$STUB_DIR/pr.json"
  echo '{"contexts":["build"]}' > "$STUB_DIR/required.json"
  echo '[]' > "$STUB_DIR/rules.json"
  echo '{"check_runs":[{"name":"build","status":"completed","conclusion":"success","started_at":"2026-01-01T00:00:00Z","html_url":"u1"},
    {"name":"lint","status":"completed","conclusion":"failure","started_at":"2026-01-01T00:00:00Z","html_url":"u2"}]}' > "$STUB_DIR/runs.json"
  echo '{"statuses":[]}' > "$STUB_DIR/status.json"
  echo '[]' > "$STUB_DIR/reviews.json"
  echo '[{"filename":"src/a.ts","status":"modified"},{"filename":"tests/x.test.ts","status":"removed"},
    {"filename":".github/workflows/ci.yml","status":"modified"},{"filename":"docs/readme.md","status":"added"}]' > "$STUB_DIR/files.json"
  echo '{"status":"ahead"}' > "$STUB_DIR/compare.json"
  echo '{"data":{"viewer":{"login":"me"},"repository":{"pullRequest":{"url":"x","reviewThreads":{"nodes":[]},
    "comments":{"nodes":[]},"reviews":{"nodes":[]}}}}}' > "$STUB_DIR/graphql.json"
}
setj() { local f="$STUB_DIR/$1" tmp; tmp=$(mktemp); jq "$2" "$f" > "$tmp" && mv "$tmp" "$f"; }
U=https://github.com/o/r/pull/7
ALL='src/**,tests/**,.github/**,docs/*.md'

# ---- status.sh -----------------------------------------------------------------------------------------------
(cd "$NR" && "$st" set active x >/dev/null 2>&1); t $? 2 "status refuses a non-git directory"
(cd "$HOME" && git init -q && "$st" set active x >/dev/null 2>&1); t $? 2 "status refuses \$HOME (symlinked temp paths too)"
CLAUDE_CODE_SESSION_ID=sessA "$st" set active "do thing" --busy 30 >/dev/null; t $? 0 "set --busy 30"
[ -n "$(sj '.busy_until // ""')" ]; t $? 0 "busy_until recorded"
t "$(sj .owner_session)" sessA "owner_session from CLAUDE_CODE_SESSION_ID"
"$st" set active "x" --busy soon >/dev/null 2>&1; t $? 2 "--busy rejects non-numbers"

# ---- stop hook -----------------------------------------------------------------------------------------------
stop() { jq -n --arg c "$R" --arg s "$1" '{cwd:$c, session_id:$s}' | "$hook"; }
t "$(stop sessA)" "" "stop hook passes while busy"
CLAUDE_CODE_SESSION_ID=sessA "$st" set active "do thing" --busy 0 >/dev/null
t "$(sj '.busy_until // "none"')" none "--busy 0 clears the lease"
t "$(stop sessB)" "" "stop hook passes for a different session_id"
t "$(stop sessA | jq -r .decision)" block "stop hook blocks the owner session when active"
CLAUDE_CODE_SESSION_ID=sessA "$st" set active "do thing" --busy 5 >/dev/null
"$st" set active "keep" >/dev/null
[ -n "$(sj '.busy_until // ""')" ]; t $? 0 "set without --busy keeps a live lease"
t "$(sj '.owner_session // "none"')" none "owner_session dropped when CLAUDE_CODE_SESSION_ID is unset"
"$st" set active "keep" --busy 0 >/dev/null
for _ in 1 2 3 4 5 6 7 8 9; do o=$(stop any); done; t "$o" "" "stop hook gives up after 8 identical stops"
"$st" set active "new action" >/dev/null
t "$(stop any | jq -r .decision)" block "a status change resets the stop counter"
t "$(jq -n --arg c "$R" '{cwd:$c}' | COORD_KEEPALIVE=0 "$hook")" "" "COORD_KEEPALIVE=0 turns the hook off"
"$st" set waiting "ci" >/dev/null
t "$(stop any)" "" "stop hook passes when waiting"

# ---- dispatch records ----------------------------------------------------------------------------------------
"$st" dispatch t1 --paths "src/**, docs/*.md" --run-id r1 >/dev/null; t $? 0 "dispatch create"
t "$(sj .dispatches.t1.base_sha)" "$(git rev-parse HEAD)" "dispatch base_sha is the worktree HEAD"
t "$(jq -c .dispatches.t1.paths "$R/.coordinator/status.json")" '["src/**","docs/*.md"]' "dispatch paths split and trimmed"
t "$(sj '.dispatches.t1 | [.state, .run_id] | join(",")')" "running,r1" "dispatch defaults to running"
"$st" dispatch t1 --state awaiting-acceptance >/dev/null; t "$(sj .dispatches.t1.state)" awaiting-acceptance "dispatch awaiting-acceptance"
"$st" dispatch t1 --state accepted >/dev/null 2>&1; t $? 4 "accepted refused without a READY pass"
t "$(sj .dispatches.t1.state)" awaiting-acceptance "refusal leaves the record unchanged"
"$st" dispatch t1 --state bogus >/dev/null 2>&1; t $? 2 "unknown dispatch state rejected"
"$st" set active "integrate" >/dev/null; t "$(sj .dispatches.t1.state)" awaiting-acceptance "dispatch records survive status set"

# ---- ready.sh (stubbed gh) -----------------------------------------------------------------------------------
fixtures
out=$("$ready" "$U" --paths "$ALL"); rc=$?
t "$rc" 0 "ready: clean PR is READY"
has "$out" "READY $U @ abc123456" "ready: header line"
has "$out" "WARN  check failed: lint" "ready: non-required failure is a warning"
has "$out" "WARN  tests deleted: tests/x.test.ts" "ready: deleted test flagged"
has "$out" "WARN  CI/test/lint config changed: .github/workflows/ci.yml" "ready: CI config change flagged"
out=$("$ready" "$U" --paths "src/**"); rc=$?
t "$rc" 1 "ready: out-of-scope files block"
has "$out" "out-of-scope files (3)" "ready: counts out-of-scope files"
out=$("$ready" "$U" --paths "**/*.ts,**/*.yml,docs/*.md"); t $? 0 "ready: ** matches any depth, including the root"
out=$("$ready" "$U" --paths "src/*,tests/*,.github/*,docs/*"); has "$out" "out-of-scope files (1)" "ready: * does not cross /"
out=$("$ready" "$U" --sha deadbeef --paths "$ALL"); t $? 1 "ready: stale --sha blocks"
has "$out" "is not the PR head" "ready: stale SHA reason"
out=$("$ready" "o/r#7" --paths "$ALL"); t $? 0 "ready: owner/repo#N form"
echo '{"contexts":["build","e2e"]}' > "$STUB_DIR/required.json"
out=$("$ready" "$U" --paths "$ALL"); has "$out" 'required check "e2e" has not reported' "ready: missing required check blocks"
fixtures; echo '[{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"lint"}]}}]' > "$STUB_DIR/rules.json"
out=$("$ready" "$U" --paths "$ALL"); has "$out" "BLOCK check failed: lint" "ready: ruleset-required check counts"
fixtures; rm "$STUB_DIR/required.json"
out=$("$ready" "$U" --paths "$ALL"); t $? 1 "ready: unreadable required list treats every check as required"
has "$out" "required-check list unreadable" "ready: warns when the required list is unreadable"
fixtures; setj runs.json '.check_runs[0].status = "in_progress"'
out=$("$ready" "$U" --paths "$ALL"); has "$out" "BLOCK check pending: build" "ready: pending required check blocks"
"$ready" "$U" --paths "$ALL" --allow-pending >/dev/null; t $? 0 "ready: --allow-pending allows pending checks"
fixtures; setj runs.json '.check_runs += [{"name":"build","status":"completed","conclusion":"failure","started_at":"2025-01-01T00:00:00Z"}]'
"$ready" "$U" --paths "$ALL" >/dev/null; t $? 0 "ready: only the latest run per check counts"
fixtures; echo '[{"state":"CHANGES_REQUESTED","user":{"login":"rev"}},{"state":"COMMENTED","user":{"login":"rev"}}]' > "$STUB_DIR/reviews.json"
out=$("$ready" "$U" --paths "$ALL"); has "$out" "changes requested by rev" "ready: latest non-comment review requesting changes blocks"
echo '[{"state":"CHANGES_REQUESTED","user":{"login":"rev"}},{"state":"APPROVED","user":{"login":"rev"}}]' > "$STUB_DIR/reviews.json"
"$ready" "$U" --paths "$ALL" >/dev/null; t $? 0 "ready: a later approval clears changes requested"
fixtures; setj pr.json '.mergeable_state = "dirty" | .mergeable = false'
out=$("$ready" "$U" --paths "$ALL"); has "$out" "merge conflicts with base" "ready: conflicts block"
fixtures; setj pr.json '.mergeable_state = "behind"'
out=$("$ready" "$U" --paths "$ALL"); has "$out" "behind base" "ready: behind blocks"
fixtures; setj pr.json '.draft = true'
out=$("$ready" "$U" --paths "$ALL"); has "$out" "PR is a draft" "ready: draft blocks"
fixtures; setj graphql.json '.data.repository.pullRequest.comments.nodes = [{"author":{"login":"alex"},"body":"please fix","url":"c1","createdAt":"2026-01-01T00:00:00Z"}]'
out=$("$ready" "$U" --paths "$ALL"); has "$out" "BLOCK reply owed: ACTION PR comment by alex" "ready: owed reply blocks"
setj graphql.json '.data.repository.pullRequest.comments.nodes += [{"author":{"login":"me"},"body":"done\n\n🤖 agent reply","url":"c2","createdAt":"2026-01-02T00:00:00Z"}]'
"$ready" "$U" --paths "$ALL" >/dev/null; t $? 0 "ready: an agent-marked reply clears the owed reply"
fixtures; rm "$STUB_DIR/graphql.json"
out=$("$ready" "$U" --paths "$ALL"); has "$out" "fail closed" "ready: unreadable reply audit fails closed"
# REST fallback when the host refuses GraphQL (Claude Code cloud sessions)
pt="$S/scripts/pr-threads.sh"
restfx() { echo '{"login":"me"}' > "$STUB_DIR/user.json"; echo '[]' > "$STUB_DIR/icomments.json"
  echo '[{"resolved":false,"outdated":false,"comment_ids":[11]},{"resolved":true,"outdated":false,"comment_ids":[12]}]' > "$STUB_DIR/threads.json"
  echo '[{"id":11,"user":{"login":"alex"},"body":"bug here","html_url":"t11","created_at":"2026-01-01T00:00:00Z","pull_request_review_id":5},
    {"id":12,"user":{"login":"bob"},"body":"nit","html_url":"t12","created_at":"2026-01-01T00:00:00Z","pull_request_review_id":5}]' > "$STUB_DIR/rcomments.json"; }
fixtures; restfx
out=$(STUB_NO_GRAPHQL=1 "$pt" "$U"); rc=$?
t "$rc" 1 "threads: GraphQL refused falls back to REST"
has "$out" "ACTION    thread by alex" "threads: REST fallback reports an unresolved thread"
hasnt "$out" "bob" "threads: REST fallback skips a resolved thread"
setj rcomments.json '. += [{"id":13,"user":{"login":"me"},"body":"fixed\n\n---\n_Generated by [Claude Code](https://claude.ai/code)_","html_url":"t13","created_at":"2026-01-02T00:00:00Z","pull_request_review_id":6}]'
setj threads.json '.[0].comment_ids += [13]'
out=$(STUB_NO_GRAPHQL=1 "$pt" "$U"); has "$out" "AWAITING  alex" "threads: the Claude Code footer counts as an agent reply"
rm "$STUB_DIR/threads.json"
STUB_NO_GRAPHQL=1 "$pt" "$U" >/dev/null 2>&1; t $? 3 "threads: a failed REST fallback is unreadable (exit 3)"
fixtures; restfx; out=$(COORD_THREADS_REST=1 "$pt" "$U"); has "$out" "ACTION    thread by alex" "threads: COORD_THREADS_REST=1 forces REST"
fixtures; echo '{"status":"diverged"}' > "$STUB_DIR/compare.json"
out=$("$ready" "$U" --paths "$ALL" --base-sha 1234567890); t $? 0 "ready: divergence from base is a warning, not a block"
has "$out" "does not descend from dispatch base" "ready: divergence warning"
fixtures; rm "$STUB_DIR/pr.json"
"$ready" "$U" >/dev/null 2>&1; t $? 3 "ready: unreadable PR exits 3"
"$ready" "not-a-pr" >/dev/null 2>&1; t $? 3 "ready: bad ref exits 3"
fixtures
"$st" dispatch t1 --pr "$U" >/dev/null
out=$("$ready" --key t1 --json); rc=$?
t "$rc" 1 "ready --key uses the dispatch paths (tests/ and .github/ out of scope)"
t "$(sj .dispatches.t1.ready.ok)" false "ready --key records the verdict"
"$st" dispatch t1 --state accepted >/dev/null 2>&1; t $? 4 "accepted refused after a failing READY"
"$st" dispatch t1 --paths "$ALL" >/dev/null
"$ready" --key t1 >/dev/null; t $? 0 "ready --key passes with widened paths"
"$st" dispatch t1 --state accepted >/dev/null; t $? 0 "accepted allowed after a READY pass"
"$ready" --key nope >/dev/null 2>&1; t $? 3 "ready --key with an unknown dispatch exits 3"

# ---- merge gate ----------------------------------------------------------------------------------------------
g() { jq -n --arg c "$1" --arg d "$2" '{tool_input:{command:$c}, cwd:$d}' | "$gate" 2> "$BIN/gate.err"; }
fixtures; echo '[]' > "$STUB_DIR/files.json"
g "git status && gh pr list" "$R"; t $? 0 "gate: non-merge command allowed"
g "gh pr merge 5 --disable-auto" "$R"; t $? 0 "gate: --disable-auto allowed"
g "gh pr merge $U --squash" "$R"; t $? 0 "gate: READY PR allowed"
setj pr.json '.mergeable_state = "dirty"'
g "gh pr merge $U --squash" "$R"; t $? 2 "gate: NOT READY PR blocked"
has "$(cat "$BIN/gate.err")" "merge conflicts with base" "gate: reason on stderr"
g "echo hi; gh api -X PUT repos/o/r/pulls/7/merge" "$R"; t $? 2 "gate: REST merge call checked"
fixtures; echo '[]' > "$STUB_DIR/files.json"; setj runs.json '.check_runs[0].status = "queued"'
g "gh pr merge $U --squash" "$R"; t $? 2 "gate: pending required check blocks a direct merge"
g "gh pr merge $U --auto --squash" "$R"; t $? 0 "gate: --auto allows pending checks"
fixtures; echo '[]' > "$STUB_DIR/files.json"
STUB_PRVIEW=1 g "gh pr merge 7 -R o/r --squash --body 'x y'" "$R"; t $? 0 "gate: number plus -R resolved via gh pr view"
g 'COORD_READY_OVERRIDE="check misread, verified green" gh pr merge https://github.com/o/r/pull/1 --squash' "$R"; t $? 0 "gate: override allowed"
grep -q "check misread, verified green" "$R/.coordinator/overrides.log"; t $? 0 "gate: override logged"
g "gh pr merge --squash" "$NR"; t $? 2 "gate: unresolvable merge in a non-repo directory fails closed"
has "$(cat "$BIN/gate.err")" "could not resolve" "gate: unresolvable reason on stderr"
rm "$STUB_DIR/pr.json"
g "gh pr merge $U" "$R"; t $? 2 "gate: unreadable PR fails closed"

echo "TOTAL pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
