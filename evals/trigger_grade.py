"""Grade a trigger run from the per-call outcome log. Called by run_trigger.sh.

  trigger_grade.py <trigger.json> <summary.md> <SKILL.md> <start> <secs> <model> <runs> <outcomes.jsonl> <isolate 1|0>

Upstream run_eval.py counts every failed `claude -p` call as "not triggered". This script ignores
upstream's trigger counts and pass flags and rebuilds them from trigger_shim.py's outcome log:

- Only "success" calls are graded. The trigger rate is triggers / successful runs.
- A query with an "error" call (or a run with no outcome line) is ERROR. A query with a "timeout"
  call is INCONCLUSIVE. Neither passes, and neither counts as a false trigger.
- Exit 1 when any call errored: the run is invalid and its numbers must not be quoted.
"""
from __future__ import annotations

import hashlib
import json
import sys

THRESHOLD = 0.5


def read_outcomes(path: str) -> dict[str, list[dict]]:
    by_query: dict[str, list[dict]] = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                o = json.loads(line)
                by_query.setdefault(o["query"], []).append(o)
    return by_query


def regrade(results: list[dict], outcomes: dict[str, list[dict]]) -> None:
    """Rewrite each result in place from its calls' outcomes."""
    for r in results:
        outs = outcomes.get(r["query"], [])
        ok = [o for o in outs if o["outcome"] == "success"]
        r["errors"] = sum(1 for o in outs if o["outcome"] == "error") + max(0, r["runs"] - len(outs))
        r["timeouts"] = sum(1 for o in outs if o["outcome"] == "timeout")
        r["graded_runs"] = len(ok)
        r["triggers"] = sum(1 for o in ok if o["triggered"])
        r["trigger_rate"] = r["triggers"] / len(ok) if ok else 0.0
        r.pop("inconclusive", None)
        r.pop("error", None)
        if r["errors"]:
            r["pass"], r["error"] = False, True
        elif r["timeouts"] or not ok:
            r["pass"], r["inconclusive"] = False, True
        elif r["should_trigger"]:
            r["pass"] = r["trigger_rate"] >= THRESHOLD
        else:
            r["pass"] = r["trigger_rate"] < THRESHOLD


def verdict(r: dict) -> str:
    return "ERROR" if r.get("error") else "INCONCLUSIVE" if r.get("inconclusive") else \
        "PASS" if r["pass"] else "FAIL"


def main(argv: list[str]) -> int:
    path, md, skill_md, start, secs, model, runs, olog, isolate = argv
    d = json.load(open(path))
    rs = d["results"]
    regrade(rs, read_outcomes(olog))
    graded = [r for r in rs if not r.get("error") and not r.get("inconclusive")]
    errored = sum(1 for r in rs if r.get("error"))
    inconclusive = sum(1 for r in rs if r.get("inconclusive"))
    error_calls = sum(r["errors"] for r in rs)
    d["summary"] = {"total": len(rs), "passed": sum(1 for r in rs if r["pass"]),
                    "errored": errored, "inconclusive": inconclusive,
                    "error_calls": error_calls, "timeout_calls": sum(r["timeouts"] for r in rs),
                    "valid": error_calls == 0}
    d["summary"]["failed"] = len(rs) - d["summary"]["passed"]
    pos = [r for r in graded if r["should_trigger"]]
    neg = [r for r in graded if not r["should_trigger"]]
    n_pos = sum(1 for r in rs if r["should_trigger"])
    n_neg = len(rs) - n_pos
    tp = sum(1 for r in pos if r["pass"])
    fp = sum(1 for r in neg if not r["pass"])
    tn = sum(1 for r in neg if r["pass"])
    calls = sum(r["runs"] for r in rs)
    prec = tp / (tp + fp) if tp + fp else 0.0
    rec = tp / n_pos if n_pos else 0.0
    pos_rate = sum(r["triggers"] for r in pos) / max(1, sum(r["graded_runs"] for r in pos))
    neg_rate = sum(r["triggers"] for r in neg) / max(1, sum(r["graded_runs"] for r in neg))
    d["meta"] = {"skill_md": skill_md, "skill_sha256": hashlib.sha256(open(skill_md, "rb").read()).hexdigest(),
                 "started_utc": start, "seconds": int(secs), "model": model, "runs_per_query": int(runs),
                 "home_isolated": isolate == "1",
                 "claude_calls": calls, "error_calls": error_calls, "errored_queries": errored,
                 "inconclusive_queries": inconclusive, "precision": round(prec, 3), "recall": round(rec, 3),
                 "should_trigger_hit_rate": round(pos_rate, 3), "should_not_false_trigger_rate": round(neg_rate, 3)}
    json.dump(d, open(path, "w"), indent=2)
    L = ["# Trigger eval summary", ""]
    if error_calls:
        L += [f"**INVALID RUN: {error_calls} `claude -p` call(s) errored in {errored} quer(ies). "
              "Errored calls are not graded. Do not quote these numbers.**", ""]
    L += [f"- Skill: `{skill_md}` (sha256 `{d['meta']['skill_sha256'][:12]}`)",
          f"- Description: {d['description']}",
          f"- Date (UTC): {start}; wall time {secs}s; model: {model}; runs per query: {runs}; `claude -p` calls: {calls}",
          f"- HOME isolated: {'yes' if isolate == '1' else 'NO (user skills and settings can affect results)'}",
          f"- Should trigger: {tp}/{n_pos} queries pass; hit rate over graded runs {pos_rate:.0%}",
          f"- Should not trigger: {tn}/{n_neg} queries pass; false-trigger rate over graded runs {neg_rate:.0%}",
          f"- Precision {prec:.2f}, recall {rec:.2f} (query level, threshold {THRESHOLD}); "
          f"errored queries: {errored}; inconclusive (timeout) queries: {inconclusive}", "",
          "| Expected | Triggers / graded runs | Result | Query |", "|---|---|---|---|"]
    order = {"ERROR": 0, "INCONCLUSIVE": 1, "FAIL": 2, "PASS": 3}
    for r in sorted(rs, key=lambda r: (not r["should_trigger"], order[verdict(r)])):
        q = r["query"].replace("|", "/").replace("\n", " ")[:120]
        L.append(f"| {'trigger' if r['should_trigger'] else 'no trigger'} | {r['triggers']}/{r['graded_runs']} | "
                 f"{verdict(r)} | {q} |")
    open(md, "w").write("\n".join(L) + "\n")
    print("\n".join(L))
    if error_calls:
        print(f"run_trigger.sh: {error_calls} call(s) errored; the run is invalid", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
