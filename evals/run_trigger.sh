#!/usr/bin/env bash
# Trigger eval: does a SKILL.md's description make Claude pick the skill for the right queries?
#   run_trigger.sh <SKILL.md or skill folder> <out dir> [--runs-per-query N] [--model M]
#                  [--num-workers N] [--timeout S] [--queries FILE]
#
# Uses skill-creator's scripts/run_eval.py from a local checkout (not vendored). Set SKILL_CREATOR to
# its folder; default /home/user/anthropics/skills/skills/skill-creator. run_eval.py writes a
# temporary command file under <project>/.claude/commands and runs `claude -p` once per query and run.
# trigger_shim.py (next to this script) gives each call its own project folder (upstream shares one,
# so parallel workers see each other's copies) and records timeouts. Everything runs in an empty
# scratch folder, so nothing is written into this repository.
# A query passes when its trigger rate is on the right side of 0.5. A query with any timed-out run is
# INCONCLUSIVE and never counts as a pass.
#
# Isolation (default on, COORD_EVAL_ISOLATE_HOME=0 turns it off): `claude -p` runs with an empty HOME
# and without CLAUDE_CODE_SYNC_SKILLS, so an installed copy of execution-coordinator cannot compete
# with the description under test. Turn it off only where auth needs the real HOME, and then check
# that no execution-coordinator skill is installed, or the results are wrong.
#
# Output: <out>/trigger.json (run_eval.py output) and <out>/trigger-summary.md.
set -euo pipefail

usage() { sed -n '2,16p' "$0"; exit 2; }
[ $# -ge 2 ] || usage
skill=$1 out=$2; shift 2
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
queries="$here/trigger-queries.json" runs=1 model="" workers=5 timeout=60
while [ $# -gt 0 ]; do
  case "$1" in
    --runs-per-query) runs=$2; shift 2;;
    --model) model=$2; shift 2;;
    --num-workers) workers=$2; shift 2;;
    --timeout) timeout=$2; shift 2;;
    --queries) queries=$2; shift 2;;
    *) usage;;
  esac
done

SC=${SKILL_CREATOR:-/home/user/anthropics/skills/skills/skill-creator}
[ -f "$SC/scripts/run_eval.py" ] || { echo "run_trigger.sh: no skill-creator at $SC (set SKILL_CREATOR)" >&2; exit 2; }
command -v claude >/dev/null || { echo "run_trigger.sh: claude CLI not on PATH" >&2; exit 2; }

[ -d "$skill" ] || skill=$(dirname "$skill")
skill=$(cd "$skill" && pwd)
[ -f "$skill/SKILL.md" ] || { echo "run_trigger.sh: no SKILL.md in $skill" >&2; exit 2; }
queries=$(cd "$(dirname "$queries")" && pwd)/$(basename "$queries")
mkdir -p "$out"; out=$(cd "$out" && pwd)

# Empty scratch project: run_eval.py finds the project root by walking up from cwd to a .claude/ dir.
proj=$(mktemp -d "${TMPDIR:-/tmp}/ec-trigger-XXXXXX")
mkdir -p "$proj/.claude"
trap 'rm -rf "$proj"' EXIT

env_args=(-u CLAUDECODE -u CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD -u CLAUDE_ADDITIONAL_DIRECTORIES)
if [ "${COORD_EVAL_ISOLATE_HOME:-1}" = 1 ]; then
  mkdir -p "$proj/home"
  env_args+=(-u CLAUDE_CODE_SYNC_SKILLS "HOME=$proj/home")
fi
model_args=(); [ -n "$model" ] && model_args=(--model "$model")

: > "$out/trigger-timeouts.txt"
start=$(date -u +%Y-%m-%dT%H:%M:%SZ); t0=$(date +%s)
(cd "$proj" && env "${env_args[@]}" COORD_TRIGGER_TIMEOUT_LOG="$out/trigger-timeouts.txt" \
  PYTHONPATH="$SC:$here" python3 -c 'import sys, trigger_shim; sys.argv[0] = "run_eval"; trigger_shim.main()' \
  --eval-set "$queries" --skill-path "$skill" --runs-per-query "$runs" \
  --num-workers "$workers" --timeout "$timeout" "${model_args[@]}" --verbose) > "$out/trigger.json"
secs=$(( $(date +%s) - t0 ))

python3 - "$out/trigger.json" "$out/trigger-summary.md" "$skill/SKILL.md" "$start" "$secs" "${model:-cli-default}" "$runs" "$out/trigger-timeouts.txt" <<'PY'
import json, sys, hashlib
path, md, skill_md, start, secs, model, runs, tlog = sys.argv[1:]
d = json.load(open(path))
rs = d["results"]
timed_out = {}
for line in open(tlog, encoding="utf-8"):
    q = line.rstrip("\n")
    timed_out[q] = timed_out.get(q, 0) + 1
for r in rs:
    r["timeouts"] = timed_out.get(r["query"].replace("\n", " "), 0)
    if r["timeouts"]:
        r["pass"] = False
        r["inconclusive"] = True
inconclusive = sum(1 for r in rs if r.get("inconclusive"))
d["summary"] = {"total": len(rs), "passed": sum(1 for r in rs if r["pass"]), "inconclusive": inconclusive}
d["summary"]["failed"] = len(rs) - d["summary"]["passed"]
pos = [r for r in rs if r["should_trigger"]]
neg = [r for r in rs if not r["should_trigger"]]
tp = sum(1 for r in pos if r["pass"]); fn = len(pos) - tp
fp = sum(1 for r in neg if not r["pass"] and not r.get("inconclusive")); tn = sum(1 for r in neg if r["pass"])
calls = sum(r["runs"] for r in rs)
prec = tp / (tp + fp) if tp + fp else 0.0
rec = tp / len(pos) if pos else 0.0
pos_rate = sum(r["triggers"] for r in pos) / max(1, sum(r["runs"] for r in pos))
neg_rate = sum(r["triggers"] for r in neg) / max(1, sum(r["runs"] for r in neg))
d["meta"] = {"skill_md": skill_md, "skill_sha256": hashlib.sha256(open(skill_md, "rb").read()).hexdigest(),
             "started_utc": start, "seconds": int(secs), "model": model, "runs_per_query": int(runs),
             "claude_calls": calls, "inconclusive_queries": inconclusive, "precision": round(prec, 3), "recall": round(rec, 3),
             "should_trigger_hit_rate": round(pos_rate, 3), "should_not_false_trigger_rate": round(neg_rate, 3)}
json.dump(d, open(path, "w"), indent=2)
L = ["# Trigger eval summary", "",
     f"- Skill: `{skill_md}` (sha256 `{d['meta']['skill_sha256'][:12]}`)",
     f"- Description: {d['description']}",
     f"- Date (UTC): {start}; wall time {secs}s; model: {model}; runs per query: {runs}; `claude -p` calls: {calls}",
     f"- Should trigger: {tp}/{len(pos)} queries pass; hit rate over runs {pos_rate:.0%}",
     f"- Should not trigger: {tn}/{len(neg)} queries pass; false-trigger rate over runs {neg_rate:.0%}",
     f"- Precision {prec:.2f}, recall {rec:.2f} (query level, threshold 0.5); inconclusive (timeout) queries: {inconclusive}", "",
     "| Expected | Triggers / runs | Result | Query |", "|---|---|---|---|"]
for r in sorted(rs, key=lambda r: (not r["should_trigger"], r["pass"])):
    q = r["query"].replace("|", "/").replace("\n", " ")[:120]
    L.append(f"| {'trigger' if r['should_trigger'] else 'no trigger'} | {r['triggers']}/{r['runs']} | "
             f"{'INCONCLUSIVE' if r.get('inconclusive') else 'PASS' if r['pass'] else 'FAIL'} | {q} |")
open(md, "w").write("\n".join(L) + "\n")
print("\n".join(L))
PY
