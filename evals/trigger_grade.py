"""Grade a trigger run from the per-call outcome log. Called by run_trigger.sh.

  trigger_grade.py <trigger-raw.json> <trigger.json> <summary.md> <SKILL.md> <start> <secs> <model> <runs>
                   <outcomes.jsonl> <isolate 1|0>

Upstream run_eval.py counts every failed `claude -p` call as "not triggered". This script ignores
upstream's trigger counts and pass flags and rebuilds them from trigger_shim.py's outcome log:

- Only "success" calls are graded. The trigger rate is triggers / successful runs.
- A query with an "error" call (or a run with no outcome line) is ERROR. A query with a "timeout"
  call is INCONCLUSIVE. Neither passes, and neither counts as a false trigger.
- Call-level rates (hit rate, false-trigger rate) use every successful call, also those of an
  inconclusive query. Query-level precision and recall use only conclusive queries.
- A rate with no graded call is None in trigger.json and "n/a" in the summary.
- Exit 1 when any call errored or no call was graded: the run is invalid and its numbers must not
  be quoted. trigger.json is written from trigger-raw.json only once grading has finished.
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


def rate(num: int, den: int) -> float | None:
    return num / den if den else None


def pct(x: float | None) -> str:
    return "n/a" if x is None else f"{x:.0%}"


def num(x: float | None) -> str:
    return "n/a" if x is None else f"{x:.2f}"


def main(argv: list[str]) -> int:
    raw, path, md, skill_md, start, secs, model, runs, olog, isolate = argv
    d = json.load(open(raw))
    rs = d["results"]
    regrade(rs, read_outcomes(olog))
    conclusive = [r for r in rs if not r.get("error") and not r.get("inconclusive")]
    errored = sum(1 for r in rs if r.get("error"))
    inconclusive = sum(1 for r in rs if r.get("inconclusive"))
    error_calls = sum(r["errors"] for r in rs)
    graded_calls = sum(r["graded_runs"] for r in rs)
    valid = error_calls == 0 and graded_calls > 0
    d["summary"] = {"total": len(rs), "passed": sum(1 for r in rs if r["pass"]),
                    "errored": errored, "inconclusive": inconclusive,
                    "error_calls": error_calls, "timeout_calls": sum(r["timeouts"] for r in rs),
                    "graded_calls": graded_calls, "valid": valid}
    d["summary"]["failed"] = len(rs) - d["summary"]["passed"]
    # Query level: conclusive queries only. Call level: every successful call.
    pos = [r for r in conclusive if r["should_trigger"]]
    neg = [r for r in conclusive if not r["should_trigger"]]
    n_pos = sum(1 for r in rs if r["should_trigger"])
    n_neg = len(rs) - n_pos
    tp = sum(1 for r in pos if r["pass"])
    fp = sum(1 for r in neg if not r["pass"])
    tn = sum(1 for r in neg if r["pass"])
    calls = sum(r["runs"] for r in rs)
    prec = rate(tp, tp + fp)
    rec = rate(tp, len(pos))
    all_pos = [r for r in rs if r["should_trigger"]]
    all_neg = [r for r in rs if not r["should_trigger"]]
    pos_rate = rate(sum(r["triggers"] for r in all_pos), sum(r["graded_runs"] for r in all_pos))
    neg_rate = rate(sum(r["triggers"] for r in all_neg), sum(r["graded_runs"] for r in all_neg))
    r3 = lambda x: None if x is None else round(x, 3)  # noqa: E731
    d["meta"] = {"skill_md": skill_md, "skill_sha256": hashlib.sha256(open(skill_md, "rb").read()).hexdigest(),
                 "started_utc": start, "seconds": int(secs), "model": model, "runs_per_query": int(runs),
                 "home_isolated": isolate == "1",
                 "claude_calls": calls, "graded_calls": graded_calls, "error_calls": error_calls,
                 "errored_queries": errored, "inconclusive_queries": inconclusive,
                 "precision": r3(prec), "recall": r3(rec),
                 "should_trigger_hit_rate": r3(pos_rate), "should_not_false_trigger_rate": r3(neg_rate)}
    L = ["# Trigger eval summary", ""]
    if not valid:
        why = (f"{error_calls} `claude -p` call(s) errored in {errored} quer(ies); errored calls are not graded"
               if error_calls else "no call was graded (every call timed out)")
        L += [f"**INVALID RUN: {why}. Do not quote these numbers.**", ""]
    L += [f"- Skill: `{skill_md}` (sha256 `{d['meta']['skill_sha256'][:12]}`)",
          f"- Description: {d['description']}",
          f"- Date (UTC): {start}; wall time {secs}s; model: {model}; runs per query: {runs}; "
          f"`claude -p` calls: {calls}; graded calls: {graded_calls}",
          f"- HOME isolated: {'yes' if isolate == '1' else 'NO (user skills and settings can affect results)'}",
          f"- Should trigger: {tp}/{n_pos} queries pass; hit rate over graded calls {pct(pos_rate)}",
          f"- Should not trigger: {tn}/{n_neg} queries pass; false-trigger rate over graded calls {pct(neg_rate)}",
          f"- Precision {num(prec)}, recall {num(rec)} (conclusive queries only, threshold {THRESHOLD}); "
          f"errored queries: {errored}; inconclusive (timeout) queries: {inconclusive}", "",
          "| Expected | Triggers / graded runs | Result | Query |", "|---|---|---|---|"]
    order = {"ERROR": 0, "INCONCLUSIVE": 1, "FAIL": 2, "PASS": 3}
    for r in sorted(rs, key=lambda r: (not r["should_trigger"], order[verdict(r)])):
        q = r["query"].replace("|", "/").replace("\n", " ")[:120]
        L.append(f"| {'trigger' if r['should_trigger'] else 'no trigger'} | {r['triggers']}/{r['graded_runs']} | "
                 f"{verdict(r)} | {q} |")
    # Grading finished: only now write trigger.json (run_trigger.sh removed any old copy).
    json.dump(d, open(path, "w"), indent=2)
    open(md, "w").write("\n".join(L) + "\n")
    print("\n".join(L))
    if not valid:
        print("run_trigger.sh: the run is invalid (" + ("errored calls" if error_calls else "nothing graded") + ")",
              file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
