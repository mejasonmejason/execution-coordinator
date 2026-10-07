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
  python3 evals/run_behavior.py --skill SKILL.md --load skill-only --out /tmp/so --runs 3   # realistic loading

Loading modes (--load):
  all         (default) SKILL.md and every references/*.md are pasted into the prompt; no tools.
              Comparable with every earlier result. It cannot see a rule that the model skips
              because it lives in a reference the model chose not to open.
  skill-only  Only SKILL.md is in the prompt. SKILL.md and references/*.md (nothing else) are
              copied into a fresh temp folder per run, and `claude -p` runs there with only the
              Read, Glob and Grep tools (--restricted keeps them inside that folder). The model
              decides itself which references to open. Each run records the files it opened.

Needs the `claude` CLI on PATH (Claude Code). No SDK. Python 3.9+, stdlib only.
A timeout, a CLI error or an unparsable grade counts as a FAIL and is marked as an error. A grade
whose "assertion" texts do not match the expectations, in order, is also a grader error.

HOME isolation (default on): `claude -p` runs with an empty temp HOME and without
CLAUDE_CODE_SYNC_SKILLS, so a user-level CLAUDE.md, settings or installed skill cannot affect the
results. Auth must then come from the environment (for example ANTHROPIC_API_KEY or
CLAUDE_CODE_OAUTH_TOKEN). --no-isolate-home keeps the real HOME; behavior.json records
"home_isolated" and summary.md labels the run.
"""
from __future__ import annotations

import argparse
import atexit
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import unicodedata
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

# skill-only: the shape Claude Code uses when a skill loads (body plus its base directory).
SKILL_ONLY_TEMPLATE = """You have this skill loaded:

Base directory for this skill: {skill_dir}

<skill>
{skill}
</skill>

User request:
<request>
{prompt}
</request>

You have read-only file tools (Read, Glob, Grep) inside the skill's base directory. You cannot run
commands or reach GitHub or any other system. Respond with what you would do and say; describe
the actions."""

SKILL_ONLY_TOOLS = "Read,Glob,Grep"

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
        atexit.register(shutil.rmtree, self.cwd, True)
        self.isolate_home = isolate_home
        drop = {"CLAUDECODE", "CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD", "CLAUDE_ADDITIONAL_DIRECTORIES"}
        self.env = {k: v for k, v in os.environ.items() if k not in drop}
        if isolate_home:
            self.env.pop("CLAUDE_CODE_SYNC_SKILLS", None)
            self.env["HOME"] = tempfile.mkdtemp(prefix="ec-evals-home-")
            atexit.register(shutil.rmtree, self.env["HOME"], True)

    def ask(self, prompt: str, model: str | None = None, cwd: str | None = None,
            read_tools: bool = False) -> dict:
        """Return {"status": ok|timeout|error, "text": str, "detail": str, "attempts": n}.

        read_tools=True is the skill-only mode: Read/Glob/Grep only, confined to `cwd`, with a
        stream-json transcript so the result also carries "tool_calls" (every tool use in order).
        """
        cmd = ["claude", "-p", "--disable-slash-commands", "--strict-mcp-config", "--no-session-persistence"]
        if read_tools:
            cmd += ["--output-format", "stream-json", "--verbose", "--tools", SKILL_ONLY_TOOLS,
                    "--allowedTools", SKILL_ONLY_TOOLS, "--permission-mode", "dontAsk", "--restricted"]
        else:
            cmd += ["--output-format", "json", "--tools", ""]
        m = model or self.model
        if m:
            cmd += ["--model", m]
        last: dict = {"status": "error", "text": "", "detail": "not run"}
        t0 = time.monotonic()
        tool_calls: list[dict] = []
        for attempt in range(1, self.retries + 2):
            with self._lock:
                self.calls += 1
            try:
                p = subprocess.run(cmd, input=prompt, capture_output=True, text=True,
                                   timeout=self.timeout, cwd=cwd or self.cwd, env=self.env)
            except subprocess.TimeoutExpired:
                last = {"status": "timeout", "text": "", "detail": f"no answer in {self.timeout}s"}
                continue
            if read_tools:
                d, tool_calls = parse_stream(p.stdout)
            else:
                try:
                    d = json.loads(p.stdout)
                except json.JSONDecodeError:
                    d = None
            if d is None:
                last = {"status": "error", "text": "", "tool_calls": tool_calls,
                        "detail": f"exit {p.returncode}; no JSON result: {p.stdout[-200:]!r} {p.stderr[:200]!r}"}
                continue
            with self._lock:
                self.models_seen.update(d.get("modelUsage", {}).keys())
                self.cost_usd += float(d.get("total_cost_usd") or 0)
            text = d.get("result") or ""
            if d.get("is_error") or p.returncode != 0 or not text.strip():
                last = {"status": "error", "text": text, "tool_calls": tool_calls,
                        "detail": f"exit {p.returncode}; is_error={d.get('is_error')}; subtype={d.get('subtype')}"}
                continue
            u = d.get("usage") or {}
            return {"status": "ok", "text": text, "detail": "", "attempts": attempt, "tool_calls": tool_calls,
                    "seconds": round(time.monotonic() - t0, 1),
                    "tokens": {"input": int(u.get("input_tokens") or 0)
                               + int(u.get("cache_read_input_tokens") or 0)
                               + int(u.get("cache_creation_input_tokens") or 0),
                               "output": int(u.get("output_tokens") or 0)},
                    "cost_usd": float(d.get("total_cost_usd") or 0)}
        last["attempts"] = self.retries + 1
        last["seconds"] = round(time.monotonic() - t0, 1)
        return last


def parse_stream(stdout: str) -> tuple[dict | None, list[dict]]:
    """Parse `--output-format stream-json` output: the final result object and every tool call.

    Each tool call is {"tool", "input", "ok"}; ok is False when its tool_result was an error
    (for example a path outside the folder). A missing result line returns None (an error).
    """
    result = None
    calls: dict[str, dict] = {}
    order: list[str] = []
    for line in stdout.splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if not isinstance(ev, dict):
            continue
        kind = ev.get("type")
        content = (ev.get("message") or {}).get("content") if kind in ("assistant", "user") else None
        if kind == "assistant" and isinstance(content, list):
            for c in content:
                if isinstance(c, dict) and c.get("type") == "tool_use":
                    cid = str(c.get("id") or len(order))
                    calls[cid] = {"tool": c.get("name"), "input": c.get("input") or {}, "ok": None}
                    order.append(cid)
        elif kind == "user" and isinstance(content, list):
            for c in content:
                if isinstance(c, dict) and c.get("type") == "tool_result" and c.get("tool_use_id") in calls:
                    calls[c["tool_use_id"]]["ok"] = not c.get("is_error")
        elif kind == "result":
            result = ev
    return result, [calls[i] for i in order]


def skill_files(skill_md: Path) -> list[tuple[str, Path]]:
    """(relative path, source) for SKILL.md and every references/*.md next to it."""
    files = [("SKILL.md", skill_md)]
    refs = skill_md.parent / "references"
    if refs.is_dir():
        files += [(f"references/{f.relative_to(refs).as_posix()}", f) for f in sorted(refs.rglob("*.md"))]
    return files


def stage_skill(skill_md: Path) -> str:
    """Copy SKILL.md and references/*.md (nothing else) into a fresh temp folder; return its path."""
    root = tempfile.mkdtemp(prefix="ec-evals-skill-")
    for rel, src in skill_files(skill_md):
        dst = Path(root) / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(src, dst)
    return root


def opened_files(tool_calls: list[dict], root: str) -> list[str]:
    """Relative paths of the files the model read successfully, in first-read order."""
    seen: list[str] = []
    real_root = os.path.realpath(root)
    for c in tool_calls:
        if c["tool"] != "Read" or not c.get("ok"):
            continue
        fp = str(c["input"].get("file_path") or "")
        full = os.path.realpath(fp if os.path.isabs(fp) else os.path.join(root, fp))
        rel = os.path.relpath(full, real_root) if full.startswith(real_root + os.sep) else fp
        if rel not in seen:
            seen.append(rel)
    return seen


def load_skill(skill_md: Path) -> str:
    """SKILL.md plus every references/*.md next to it, each with a path header."""
    parts = [f"=== {skill_md.name} ===\n{skill_md.read_text(encoding='utf-8')}"]
    refs = skill_md.parent / "references"
    if refs.is_dir():
        for f in sorted(refs.rglob("*.md")):
            parts.append(f"=== references/{f.relative_to(refs)} ===\n{f.read_text(encoding='utf-8')}")
    return "\n\n".join(parts)


_QUOTES = str.maketrans({"\u2018": "'", "\u2019": "'", "\u201c": '"', "\u201d": '"',
                         "\u2013": "-", "\u2014": "-"})


def norm_assertion(text: str) -> str:
    """Compare assertion texts loosely: case, spacing, quote style, a leading "1." and the
    trailing full stop do not matter. The words do."""
    t = unicodedata.normalize("NFKC", str(text)).translate(_QUOTES).strip().strip('"').strip()
    t = re.sub(r"^\d+[.)]\s+", "", t)
    return " ".join(t.lower().split()).rstrip(".")


def parse_grades(text: str, expectations: list[str]) -> tuple[list[dict] | None, str]:
    """Return (grades, "") or (None, reason). Each returned object must name its expectation:
    its "assertion" must match the expectation at the same position. A grade for another
    assertion, or the right ones out of order, is a grader error, never a pass (issue #24)."""
    start, end = text.find("["), text.rfind("]")
    if start < 0 or end <= start:
        return None, "no JSON array"
    try:
        arr = json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return None, "invalid JSON"
    if not isinstance(arr, list) or len(arr) != len(expectations):
        n = len(arr) if isinstance(arr, list) else "not a list"
        return None, f"expected {len(expectations)} grades, got {n}"
    out = []
    for i, (exp, g) in enumerate(zip(expectations, arr), 1):
        if not isinstance(g, dict) or not isinstance(g.get("pass"), bool):
            return None, f"grade {i} has no boolean pass"
        if norm_assertion(g.get("assertion", "")) != norm_assertion(exp):
            return None, f"grade {i} names another assertion: {str(g.get('assertion', ''))[:120]!r}"
        out.append({"text": exp, "passed": g["pass"], "evidence": str(g.get("evidence", "")), "status": "ok"})
    return out, ""


def grade(claude: Claude, grader_model: str | None, prompt: str, answer: str,
          expectations: list[str]) -> dict:
    listing = "\n".join(f"{i + 1}. {e}" for i, e in enumerate(expectations))
    r = claude.ask(GRADER_TEMPLATE.format(prompt=prompt, answer=answer, expectations=listing,
                                          n=len(expectations)), model=grader_model)
    grades, why = parse_grades(r["text"], expectations) if r["status"] == "ok" else (None, "")
    if grades is None:
        status = r["status"] if r["status"] != "ok" else "unparsable"
        detail = why or r["detail"] or r["text"][:200]
        grades = [{"text": e, "passed": False, "evidence": f"GRADER {status}: {detail}",
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
    ap.add_argument("--load", choices=["all", "skill-only"], default="all",
                    help="all (default): SKILL.md + every reference in the prompt, no tools. "
                         "skill-only: SKILL.md in the prompt; references readable with Read/Glob/Grep")
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
    ap.add_argument("--no-isolate-home", dest="isolate_home", action="store_false",
                    help="keep the real HOME. Default: an empty HOME, which hides user skills, settings and "
                         "CLAUDE.md and needs env-based auth. The output records which one ran")
    ap.add_argument("--isolate-home", dest="isolate_home", action="store_true",
                    help="the default; kept so older commands still work")
    args = ap.parse_args()
    if args.runs < 1:
        ap.error("--runs must be 1 or more")
    if args.no_skill == bool(args.skill):
        ap.error("give exactly one of --skill PATH or --no-skill")
    if args.no_skill and args.load != "all":
        ap.error("--load skill-only needs --skill")
    skill_only = args.load == "skill-only"

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

    def answer_prompt(e: dict, skill_dir: str = "") -> str:
        if args.no_skill:
            return NO_SKILL_TEMPLATE.format(prompt=e["prompt"])
        if skill_only:
            assert skill_md is not None
            return SKILL_ONLY_TEMPLATE.format(skill_dir=skill_dir, prompt=e["prompt"],
                                              skill=skill_md.read_text(encoding="utf-8"))
        return ANSWER_TEMPLATE.format(skill=skill_text, prompt=e["prompt"])

    def run_one(e: dict, n: int) -> dict:
        reads: dict = {}
        if skill_only:
            assert skill_md is not None
            skill_dir = stage_skill(skill_md)
            try:
                r = claude.ask(answer_prompt(e, skill_dir), cwd=skill_dir, read_tools=True)
            finally:
                shutil.rmtree(skill_dir, ignore_errors=True)
            calls = r.get("tool_calls") or []
            opened = opened_files(calls, skill_dir)
            reads = {"files_opened": opened,
                     "references_opened": [f for f in opened if f.startswith("references/")],
                     "tool_calls": [{"tool": c["tool"], "ok": c["ok"],
                                     "arg": str(c["input"].get("file_path") or c["input"].get("pattern") or "")
                                     .replace(skill_dir, "<skill_dir>")} for c in calls]}
        else:
            r = claude.ask(answer_prompt(e))
        fname = f"answers/{e['name']}.md" if args.runs == 1 else f"answers/{e['name']}.run{n}.md"
        (out / fname).write_text(
            r["text"] if r["status"] == "ok" else f"ANSWER {r['status']}: {r['detail']}\n{r['text']}", encoding="utf-8")
        row = {"run": n, "answer_status": r["status"], "answer_attempts": r.get("attempts"), "answer_file": fname,
               **reads,
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
        opened_note = (f", opened {', '.join(reads['references_opened']) or 'no references'}"
                       if skill_only else "")
        print(f"[eval] {e['name']} run {n}: {row['summary']['passed']}/{row['summary']['total']} "
              f"(answer {r['status']}, grader {row['grader_status']}, {row['answer_words']} words, "
              f"{row['answer_seconds']}s{opened_note})", file=sys.stderr)
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
            **({"references_opened": count_refs(runs)} if skill_only else {}),
        })

    all_runs = [r for row in rows for r in row["runs"]]
    all_exps = [x for r in all_runs for x in r["expectations"]]
    errors = sum(1 for x in all_exps if x.get("status") != "ok")
    result = {
        "mode": "no-skill" if args.no_skill else "skill",
        "load": None if args.no_skill else args.load,
        "skill_md_chars": len(skill_md.read_text(encoding="utf-8")) if skill_md else 0,
        "skill_references": [rel for rel, _ in skill_files(skill_md)][1:] if skill_md else [],
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
        "home_isolated": args.isolate_home,
        "summary": {**summarize(all_exps), "evals": len(rows), "runs": len(all_runs),
                    "runs_all_passed": sum(1 for r in all_runs if r["all_passed"]),
                    "errored_expectations": errors,
                    "answer_words": spread([r["answer_words"] for r in all_runs if r["answer_status"] == "ok"]),
                    "answer_seconds": spread([r["answer_seconds"] or 0 for r in all_runs
                                              if r["answer_status"] == "ok"]),
                    "goldens": len(goldens), "goldens_caught": sum(1 for g in goldens if g["golden_caught"]),
                    **({"references_opened": count_refs(all_runs)} if skill_only else {})},
        "evals": rows,
        "goldens": goldens,
    }
    (out / "behavior.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    (out / "summary.md").write_text(render_summary(result), encoding="utf-8")
    print(render_summary(result))
    if errors and args.isolate_home:
        print("note: HOME was isolated. If the errors are auth errors, set ANTHROPIC_API_KEY or "
              "CLAUDE_CODE_OAUTH_TOKEN, or pass --no-isolate-home.", file=sys.stderr)
    # Exit 1 when a golden is not caught (toothless assertions) or a call errored.
    return 1 if (goldens and result["summary"]["goldens_caught"] < len(goldens)) or errors else 0


def count_refs(runs: list[dict]) -> dict[str, int]:
    """How many of these runs opened each reference file."""
    counts: dict[str, int] = {}
    for r in runs:
        for f in r.get("references_opened") or []:
            counts[f] = counts.get(f, 0) + 1
    return dict(sorted(counts.items()))


def _refs_cell(counts: dict[str, int], runs: int) -> str:
    if not counts:
        return "none"
    return ", ".join(f"{k.removeprefix('references/')} {v}/{runs}" for k, v in counts.items())


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
    if "home_isolated" in r:
        lines.append("- HOME isolated: yes" if r["home_isolated"] else
                     "- HOME isolated: NO (user-level CLAUDE.md, settings and skills can affect results)")
    skill_only = r.get("load") == "skill-only"
    if r.get("load"):
        lines.append(
            "- Loading: skill-only. The prompt holds SKILL.md only; SKILL.md and references/*.md are in a "
            "temp folder the model can read with Read/Glob/Grep. References available: "
            f"{', '.join(r['skill_references']) or 'none'}" if skill_only else
            "- Loading: all. SKILL.md and every references/*.md are in the prompt; no tools.")
    if s["runs"]:
        lines += [
            f"- Expectations passed: {s['passed']}/{s['total']} ({s['pass_rate']:.0%}); "
            f"runs with every expectation passed: {s['runs_all_passed']}/{s['runs']}; "
            f"errored expectations (timeout/CLI/grader): {s['errored_expectations']}",
            f"- Answer length: mean {s['answer_words']['mean']:.0f} words "
            f"({s['answer_words']['min']:.0f} to {s['answer_words']['max']:.0f}); "
            f"answer time: mean {s['answer_seconds']['mean']:.0f}s",
        ]
    if skill_only and s["runs"]:
        lines.append(f"- References opened (runs that read each file): "
                     f"{_refs_cell(s.get('references_opened') or {}, s['runs'])}")
    lines += [f"- Goldens caught (every key expectation FAILS): {s['goldens_caught']}/{s['goldens']}", ""]
    if r["evals"]:
        refs_head = " References opened (runs) |" if skill_only else ""
        lines += ["## Per eval", "",
                  "| Eval | Mean pass rate | Min to max | Runs fully passed | Mean words | Mean seconds | Mean output tokens |"
                  + refs_head,
                  "|---|---|---|---|---|---|---|" + ("---|" if skill_only else "")]
        for e in r["evals"]:
            pr = e["pass_rate"]
            refs_col = f" {_refs_cell(e.get('references_opened') or {}, len(e['runs']))} |" if skill_only else ""
            lines.append(f"| {e['name']} | {pr['mean']:.0%} | {pr['min']:.0%} to {pr['max']:.0%} | "
                         f"{e['runs_all_passed']}/{len(e['runs'])} | {e['answer_words']['mean']:.0f} | "
                         f"{e['answer_seconds']['mean']:.0f} | {e['answer_output_tokens']['mean']:.0f} |"
                         + refs_col)
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
