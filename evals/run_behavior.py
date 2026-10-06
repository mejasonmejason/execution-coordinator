#!/usr/bin/env python3
"""Behavior evals for the execution-coordinator skill.

For one SKILL.md, this script:
  1. sends each eval prompt in evals.json to `claude -p` with the skill text in the prompt,
  2. grades each answer against the eval's expectations with a separate `claude -p` call,
  3. grades each golden (a known-bad answer) the same way; every golden must FAIL,
  4. writes behavior.json, summary.md and the raw answers to --out.

Usage:
  python3 evals/run_behavior.py --skill SKILL.md --out evals/results/v10
  python3 evals/run_behavior.py --skill /path/to/v11/SKILL.md --out /tmp/v11 --only stack-merge-order
  python3 evals/run_behavior.py --skill SKILL.md --out /tmp/g --goldens-only
  python3 evals/run_behavior.py --skill SKILL.md --out /tmp/v10x3 --runs 3      # mean and min-max per eval
  python3 evals/run_behavior.py --no-skill --out /tmp/bare --runs 3             # baseline: no skill text

Needs the `claude` CLI on PATH (Claude Code). No API key or SDK. Python 3.9+, stdlib only.
A timeout, a CLI error or an unparsable grade counts as a FAIL and is marked as an error.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import subprocess
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent

ANSWER_TEMPLATE = """You have this skill loaded:

<skill>
{skill}
</skill>

User request:
<request>
{prompt}
</request>

Respond with what you would do and say. You cannot run tools; describe the actions."""

NO_SKILL_TEMPLATE = """User request:
<request>
{prompt}
</request>

Respond with what you would do and say. You cannot run tools; describe the actions."""

GRADER_TEMPLATE = """You are a strict grader of an AI agent's answer. The agent could not run tools, so a
clear statement of what it does or will do counts as doing it. Grade every EXPECTATION against
the ANSWER text only.

Rules:
- An expectation passes only if the answer clearly says or does it. Vague or merely implied is a fail.
- If any part of the answer contradicts the expectation, it fails.
- Do not reward the answer for things the expectation does not ask about.

USER REQUEST:
<request>
{prompt}
</request>

ANSWER:
<answer>
{answer}
</answer>

EXPECTATIONS (in order):
{expectations}

Return ONLY a JSON array with exactly {n} objects, in the same order, and no other text:
[{{"assertion": "<expectation text>", "pass": true or false, "evidence": "<short quote from the answer, or why it fails>"}}]"""


class Claude:
    """Runs `claude -p` with no tools, no skills and no MCP servers, from an empty directory."""

    def __init__(self, model: str | None, timeout: int, retries: int, isolate_home: bool):
        self.model = model
        self.timeout = timeout
        self.retries = retries
        self.calls = 0
        self.models_seen: set[str] = set()
        self.cost_usd = 0.0
        self._lock = threading.Lock()
        self.cwd = tempfile.mkdtemp(prefix="ec-evals-cwd-")
        drop = {"CLAUDECODE", "CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD", "CLAUDE_ADDITIONAL_DIRECTORIES"}
        self.env = {k: v for k, v in os.environ.items() if k not in drop}
        if isolate_home:
            self.env.pop("CLAUDE_CODE_SYNC_SKILLS", None)
            self.env["HOME"] = tempfile.mkdtemp(prefix="ec-evals-home-")

    def ask(self, prompt: str, model: str | None = None) -> dict:
        """Return {"status": ok|timeout|error, "text": str, "detail": str, "attempts": n}."""
        cmd = ["claude", "-p", "--output-format", "json", "--tools", "", "--disable-slash-commands",
               "--strict-mcp-config", "--no-session-persistence"]
        m = model or self.model
        if m:
            cmd += ["--model", m]
        last = {"status": "error", "text": "", "detail": "not run"}
        t0 = time.monotonic()
        for attempt in range(1, self.retries + 2):
            with self._lock:
                self.calls += 1
            try:
                p = subprocess.run(cmd, input=prompt, capture_output=True, text=True,
                                   timeout=self.timeout, cwd=self.cwd, env=self.env)
            except subprocess.TimeoutExpired:
                last = {"status": "timeout", "text": "", "detail": f"no answer in {self.timeout}s"}
                continue
            try:
                d = json.loads(p.stdout)
            except json.JSONDecodeError:
                last = {"status": "error", "text": "",
                        "detail": f"exit {p.returncode}; stdout not JSON: {p.stdout[:200]!r} {p.stderr[:200]!r}"}
                continue
            with self._lock:
                self.models_seen.update(d.get("modelUsage", {}).keys())
                self.cost_usd += float(d.get("total_cost_usd") or 0)
            text = d.get("result") or ""
            if d.get("is_error") or p.returncode != 0 or not text.strip():
                last = {"status": "error", "text": text, "detail": f"exit {p.returncode}; is_error={d.get('is_error')}"}
                continue
            u = d.get("usage") or {}
            return {"status": "ok", "text": text, "detail": "", "attempts": attempt,
                    "seconds": round(time.monotonic() - t0, 1),
                    "tokens": {"input": int(u.get("input_tokens") or 0)
                               + int(u.get("cache_read_input_tokens") or 0)
                               + int(u.get("cache_creation_input_tokens") or 0),
                               "output": int(u.get("output_tokens") or 0)},
                    "cost_usd": float(d.get("total_cost_usd") or 0)}
        last["attempts"] = self.retries + 1
        last["seconds"] = round(time.monotonic() - t0, 1)
        return last


def load_skill(skill_md: Path) -> str:
    """SKILL.md plus every references/*.md next to it, each with a path header."""
    parts = [f"=== {skill_md.name} ===\n{skill_md.read_text(encoding='utf-8')}"]
    refs = skill_md.parent / "references"
    if refs.is_dir():
        for f in sorted(refs.rglob("*.md")):
            parts.append(f"=== references/{f.relative_to(refs)} ===\n{f.read_text(encoding='utf-8')}")
    return "\n\n".join(parts)


def parse_grades(text: str, expectations: list[str]) -> list[dict] | None:
    start, end = text.find("["), text.rfind("]")
    if start < 0 or end <= start:
        return None
    try:
        arr = json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return None
    if not isinstance(arr, list) or len(arr) != len(expectations):
        return None
    out = []
    for exp, g in zip(expectations, arr):
        if not isinstance(g, dict) or not isinstance(g.get("pass"), bool):
            return None
        out.append({"text": exp, "passed": g["pass"], "evidence": str(g.get("evidence", "")), "status": "ok"})
    return out


def grade(claude: Claude, grader_model: str | None, prompt: str, answer: str,
          expectations: list[str]) -> dict:
    listing = "\n".join(f"{i + 1}. {e}" for i, e in enumerate(expectations))
    r = claude.ask(GRADER_TEMPLATE.format(prompt=prompt, answer=answer, expectations=listing,
                                          n=len(expectations)), model=grader_model)
    grades = parse_grades(r["text"], expectations) if r["status"] == "ok" else None
    if grades is None:
        status = r["status"] if r["status"] != "ok" else "unparsable"
        grades = [{"text": e, "passed": False, "evidence": f"GRADER {status}: {r['detail'] or r['text'][:200]}",
                   "status": "grader_error"} for e in expectations]
        return {"status": status, "expectations": grades, "raw": r["text"]}
    return {"status": "ok", "expectations": grades, "raw": r["text"]}


def summarize(exps: list[dict]) -> dict:
    passed = sum(1 for e in exps if e["passed"])
    return {"passed": passed, "failed": len(exps) - passed, "total": len(exps),
            "pass_rate": round(passed / len(exps), 3) if exps else 0.0}


def spread(values: list[float]) -> dict:
    if not values:
        return {"mean": 0.0, "min": 0.0, "max": 0.0}
    return {"mean": round(sum(values) / len(values), 3), "min": round(min(values), 3), "max": round(max(values), 3)}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--skill", help="path to the SKILL.md to test (or its folder)")
    ap.add_argument("--no-skill", action="store_true",
                    help="baseline: send the same prompts with no skill text (goldens are still graded)")
    ap.add_argument("--out", required=True, help="output directory")
    ap.add_argument("--evals", default=str(HERE / "evals.json"))
    ap.add_argument("--runs", type=int, default=1, help="answers per eval; the summary shows mean and min-max")
    ap.add_argument("--model", default=None, help="model for answers (default: CLI default)")
    ap.add_argument("--grader-model", default=None, help="model for grading (default: CLI default)")
    ap.add_argument("--concurrency", type=int, default=4)
    ap.add_argument("--timeout", type=int, default=420, help="seconds per claude -p call")
    ap.add_argument("--retries", type=int, default=1, help="extra attempts after a timeout or CLI error")
    ap.add_argument("--only", default="", help="comma-separated eval names or ids")
    ap.add_argument("--goldens-only", action="store_true", help="grade the goldens only (no answers)")
    ap.add_argument("--no-goldens", action="store_true")
    ap.add_argument("--isolate-home", action="store_true",
                    help="run claude with an empty HOME (hides user skills and CLAUDE.md; needs env-based auth)")
    args = ap.parse_args()
    if args.runs < 1:
        ap.error("--runs must be 1 or more")
    if args.no_skill == bool(args.skill):
        ap.error("give exactly one of --skill PATH or --no-skill")

    skill_md: Path | None = None
    skill_text = ""
    if args.skill:
        skill_md = Path(args.skill).resolve()
        if skill_md.is_dir():
            skill_md = skill_md / "SKILL.md"
        if not skill_md.is_file():
            print(f"no SKILL.md at {skill_md}", file=sys.stderr)
            return 2
        skill_text = load_skill(skill_md)
    spec = json.loads(Path(args.evals).read_text(encoding="utf-8"))
    evals = spec["evals"]
    if args.only:
        wanted = {s.strip() for s in args.only.split(",") if s.strip()}
        evals = [e for e in evals if e["name"] in wanted or str(e["id"]) in wanted]
    out = Path(args.out)
    (out / "answers").mkdir(parents=True, exist_ok=True)

    claude = Claude(args.model, args.timeout, args.retries, args.isolate_home)
    started = dt.datetime.now(dt.timezone.utc)
    evals_dir = Path(args.evals).resolve().parent

    def exps_of(e: dict) -> list[str]:
        return e.get("expectations") or e.get("assertions") or []

    def answer_prompt(e: dict) -> str:
        if args.no_skill:
            return NO_SKILL_TEMPLATE.format(prompt=e["prompt"])
        return ANSWER_TEMPLATE.format(skill=skill_text, prompt=e["prompt"])

    def run_one(e: dict, n: int) -> dict:
        r = claude.ask(answer_prompt(e))
        fname = f"answers/{e['name']}.md" if args.runs == 1 else f"answers/{e['name']}.run{n}.md"
        (out / fname).write_text(
            r["text"] if r["status"] == "ok" else f"ANSWER {r['status']}: {r['detail']}\n{r['text']}", encoding="utf-8")
        row = {"run": n, "answer_status": r["status"], "answer_attempts": r.get("attempts"), "answer_file": fname,
               "answer_words": len(r["text"].split()) if r["status"] == "ok" else 0,
               "answer_seconds": r.get("seconds"), "answer_tokens": r.get("tokens"),
               "answer_cost_usd": r.get("cost_usd")}
        if r["status"] != "ok":
            row["expectations"] = [{"text": x, "passed": False, "evidence": f"ANSWER {r['status']}: {r['detail']}",
                                    "status": "answer_error"} for x in exps_of(e)]
            row["grader_status"] = "skipped"
        else:
            g = grade(claude, args.grader_model, e["prompt"], r["text"], exps_of(e))
            row["expectations"], row["grader_status"] = g["expectations"], g["status"]
        row["summary"] = summarize(row["expectations"])
        row["all_passed"] = row["summary"]["failed"] == 0
        print(f"[eval] {e['name']} run {n}: {row['summary']['passed']}/{row['summary']['total']} "
              f"(answer {r['status']}, grader {row['grader_status']}, {row['answer_words']} words, "
              f"{row['answer_seconds']}s)", file=sys.stderr)
        return row

    def run_golden(e: dict) -> dict:
        path = evals_dir / e.get("golden", f"goldens/{e['name']}.md")
        answer = path.read_text(encoding="utf-8")
        g = grade(claude, args.grader_model, e["prompt"], answer, exps_of(e))
        keys = e.get("key_expectations") or list(range(len(exps_of(e))))
        graded_ok = g["status"] == "ok"
        key_failed = graded_ok and all(not g["expectations"][i]["passed"] for i in keys)
        row = {"id": e["id"], "name": e["name"], "golden_file": str(path.relative_to(evals_dir)),
               "grader_status": g["status"], "expectations": g["expectations"],
               "summary": summarize(g["expectations"]), "key_expectations": keys,
               # A golden is caught when the grade is readable and every key expectation fails.
               "golden_caught": key_failed}
        print(f"[golden] {e['name']}: {'caught' if key_failed else 'NOT CAUGHT'} (grader {g['status']})",
              file=sys.stderr)
        return row

    with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
        golden_f = [] if args.no_goldens else [pool.submit(run_golden, e) for e in evals]
        run_f = [] if args.goldens_only else [(e, pool.submit(run_one, e, n))
                                               for e in evals for n in range(1, args.runs + 1)]
        goldens = [f.result() for f in golden_f]
        runs_by_eval: dict[str, list[dict]] = {}
        for e, f in run_f:
            runs_by_eval.setdefault(e["name"], []).append(f.result())

    rows = []
    for e in evals:
        runs = runs_by_eval.get(e["name"])
        if not runs:
            continue
        per_exp = []
        for i, text in enumerate(exps_of(e)):
            per_exp.append({"text": text, "passed_runs": sum(1 for r in runs if r["expectations"][i]["passed"]),
                            "runs": len(runs)})
        ok_runs = [r for r in runs if r["answer_status"] == "ok"]
        rows.append({
            "id": e["id"], "name": e["name"], "runs": runs,
            "pass_rate": spread([r["summary"]["pass_rate"] for r in runs]),
            "runs_all_passed": sum(1 for r in runs if r["all_passed"]),
            "per_expectation": per_exp,
            "answer_words": spread([r["answer_words"] for r in ok_runs]),
            "answer_seconds": spread([r["answer_seconds"] or 0 for r in ok_runs]),
            "answer_output_tokens": spread([(r["answer_tokens"] or {}).get("output", 0) for r in ok_runs]),
        })

    all_runs = [r for row in rows for r in row["runs"]]
    all_exps = [x for r in all_runs for x in r["expectations"]]
    errors = sum(1 for x in all_exps if x.get("status") != "ok")
    result = {
        "mode": "no-skill" if args.no_skill else "skill",
        "skill_path": str(skill_md) if skill_md else None,
        "skill_sha256": hashlib.sha256(skill_text.encode()).hexdigest() if skill_text else None,
        "skill_chars": len(skill_text),
        "started_utc": started.isoformat(timespec="seconds"),
        "finished_utc": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "answer_model_requested": args.model or "cli-default",
        "grader_model_requested": args.grader_model or "cli-default",
        "models_seen": sorted(claude.models_seen),
        "claude_calls": claude.calls,
        "cost_usd_reported": round(claude.cost_usd, 4),
        "runs_per_eval": args.runs,
        "concurrency": args.concurrency, "timeout_s": args.timeout, "retries": args.retries,
        "summary": {**summarize(all_exps), "evals": len(rows), "runs": len(all_runs),
                    "runs_all_passed": sum(1 for r in all_runs if r["all_passed"]),
                    "errored_expectations": errors,
                    "answer_words": spread([r["answer_words"] for r in all_runs if r["answer_status"] == "ok"]),
                    "answer_seconds": spread([r["answer_seconds"] or 0 for r in all_runs
                                              if r["answer_status"] == "ok"]),
                    "goldens": len(goldens), "goldens_caught": sum(1 for g in goldens if g["golden_caught"])},
        "evals": rows,
        "goldens": goldens,
    }
    (out / "behavior.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    (out / "summary.md").write_text(render_summary(result), encoding="utf-8")
    print(render_summary(result))
    # Exit 1 when a golden is not caught (toothless assertions) or a call errored.
    return 1 if (goldens and result["summary"]["goldens_caught"] < len(goldens)) or errors else 0


def _cell(x: str, n: int) -> str:
    return x.replace("|", "/").replace("\n", " ")[:n]


def render_summary(r: dict) -> str:
    s = r["summary"]
    skill = (f"`{r['skill_path']}` (sha256 of skill text `{r['skill_sha256'][:12]}`, {r['skill_chars']} chars)"
             if r["skill_path"] else "none (no-skill baseline: same prompts, no skill text)")
    lines = [
        "# Behavior eval summary", "",
        f"- Skill: {skill}",
        f"- Date (UTC): {r['started_utc']} to {r['finished_utc']}",
        f"- Answer model: {r['answer_model_requested']}; grader model: {r['grader_model_requested']}; "
        f"models seen: {', '.join(r['models_seen']) or 'unknown'}",
        f"- Runs per eval: {r['runs_per_eval']}; `claude -p` calls: {r['claude_calls']} "
        f"(reported cost ${r['cost_usd_reported']})",
    ]
    if s["runs"]:
        lines += [
            f"- Expectations passed: {s['passed']}/{s['total']} ({s['pass_rate']:.0%}); "
            f"runs with every expectation passed: {s['runs_all_passed']}/{s['runs']}; "
            f"errored expectations (timeout/CLI/grader): {s['errored_expectations']}",
            f"- Answer length: mean {s['answer_words']['mean']:.0f} words "
            f"({s['answer_words']['min']:.0f} to {s['answer_words']['max']:.0f}); "
            f"answer time: mean {s['answer_seconds']['mean']:.0f}s",
        ]
    lines += [f"- Goldens caught (every key expectation FAILS): {s['goldens_caught']}/{s['goldens']}", ""]
    if r["evals"]:
        lines += ["## Per eval", "",
                  "| Eval | Mean pass rate | Min to max | Runs fully passed | Mean words | Mean seconds | Mean output tokens |",
                  "|---|---|---|---|---|---|---|"]
        for e in r["evals"]:
            pr = e["pass_rate"]
            lines.append(f"| {e['name']} | {pr['mean']:.0%} | {pr['min']:.0%} to {pr['max']:.0%} | "
                         f"{e['runs_all_passed']}/{len(e['runs'])} | {e['answer_words']['mean']:.0f} | "
                         f"{e['answer_seconds']['mean']:.0f} | {e['answer_output_tokens']['mean']:.0f} |")
        lines += ["", "## Per expectation", "",
                  "| Eval | # | Passed runs | Expectation | Evidence (run 1) |", "|---|---|---|---|---|"]
        for e in r["evals"]:
            for i, x in enumerate(e["per_expectation"]):
                ev = e["runs"][0]["expectations"][i]
                tag = "" if ev.get("status") == "ok" else " (error)"
                lines.append(f"| {e['name']} | {i + 1} | {x['passed_runs']}/{x['runs']}{tag} | "
                             f"{_cell(x['text'], 110)} | {_cell(ev['evidence'], 160)} |")
        lines.append("")
    if r["goldens"]:
        lines += ["## Goldens (must FAIL)", "", "| Eval | Key expectations | Golden passed | Verdict |",
                  "|---|---|---|---|"]
        for g in r["goldens"]:
            keys = ", ".join(f"#{i + 1}" for i in g["key_expectations"])
            lines.append(f"| {g['name']} | {keys} | {g['summary']['passed']}/{g['summary']['total']} | "
                         f"{'caught' if g['golden_caught'] else 'NOT CAUGHT (' + g['grader_status'] + ')'} |")
        lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    sys.exit(main())
