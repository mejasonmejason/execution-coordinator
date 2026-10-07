#!/usr/bin/env bash
# Trigger eval: does a SKILL.md's description make Claude pick the skill for the right queries?
#   run_trigger.sh <SKILL.md or skill folder> <out dir> [--runs-per-query N] [--model M]
#                  [--num-workers N] [--timeout S] [--queries FILE]
#
# Uses skill-creator's scripts/run_eval.py from a local checkout (not vendored). Set SKILL_CREATOR to
# its folder; default /home/user/anthropics/skills/skills/skill-creator. run_eval.py writes a
# temporary command file under <project>/.claude/commands and runs `claude -p` once per query and run.
# trigger_shim.py (next to this script) gives each call its own project folder (upstream shares one,
# so parallel workers see each other's copies) and records each call's outcome: success, error or
# timeout. Everything runs in an empty scratch folder, so nothing is written into this repository.
# Only successful calls are graded. A query passes when its trigger rate over its successful runs is
# on the right side of 0.5. A query with any errored run is ERROR, a query with any timed-out run is
# INCONCLUSIVE, and neither counts as a pass. Any errored call makes this script exit 1: the run is
# invalid (for example an auth error or an unknown model), and its numbers must not be quoted.
#
# Isolation (default on, COORD_EVAL_ISOLATE_HOME=0 turns it off): `claude -p` runs with an empty HOME
# and without CLAUDE_CODE_SYNC_SKILLS, so an installed copy of execution-coordinator cannot compete
# with the description under test. Turn it off only where auth needs the real HOME, and then check
# that no execution-coordinator skill is installed, or the results are wrong.
#
# Output: <out>/trigger.json (run_eval.py output, regraded), <out>/trigger-summary.md and
# <out>/trigger-outcomes.jsonl (one line per `claude -p` call).
set -euo pipefail

usage() { sed -n '2,23p' "$0"; exit 2; }
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

: > "$out/trigger-outcomes.jsonl"
start=$(date -u +%Y-%m-%dT%H:%M:%SZ); t0=$(date +%s)
(cd "$proj" && env "${env_args[@]}" COORD_TRIGGER_OUTCOME_LOG="$out/trigger-outcomes.jsonl" \
  PYTHONPATH="$SC:$here" python3 -c 'import sys, trigger_shim; sys.argv[0] = "run_eval"; trigger_shim.main()' \
  --eval-set "$queries" --skill-path "$skill" --runs-per-query "$runs" \
  --num-workers "$workers" --timeout "$timeout" "${model_args[@]}" --verbose) > "$out/trigger.json"
secs=$(( $(date +%s) - t0 ))

python3 "$here/trigger_grade.py" "$out/trigger.json" "$out/trigger-summary.md" "$skill/SKILL.md" "$start" "$secs" "${model:-cli-default}" "$runs" "$out/trigger-outcomes.jsonl" "${COORD_EVAL_ISOLATE_HOME:-1}"
