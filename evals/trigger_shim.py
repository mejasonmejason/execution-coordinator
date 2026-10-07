"""Replacement for run_single_query in skill-creator's scripts/run_eval.py (imported from the local
checkout, not vendored). The rest of run_eval.py (query loop, workers, output) is unchanged.

This module changes three things:

1. One project folder per query. Upstream run_eval.py writes every worker's temporary command file
   into one shared <project>/.claude/commands folder. With more than one worker, each `claude -p`
   then sees several copies of the skill (one per worker, each with its own uuid) and often picks
   another worker's copy, which counts as "not triggered". Measured 2026-10-06 with 5 workers: a
   query that triggered 3 of 4 times on its own scored 0 of 3. Here each call gets its own folder.
2. Every call has an explicit outcome: "success", "error" or "timeout". Upstream returns False
   ("not triggered") for all three, so a failed call scores as a pass for a should-not-trigger
   query. Before this change only slow failures were caught (by elapsed time); a fast failure, such
   as an auth error or an unknown model, returned in about one second and was graded as a pass
   (issue #24). An error is: an assistant message with an "error" field, a result with
   is_error=true, or a process that exits before the stream says whether the skill triggered.
3. Each outcome is appended as one JSON line to $COORD_TRIGGER_OUTCOME_LOG:
   {"query", "outcome", "triggered", "detail"}. run_trigger.sh grades only the "success" calls,
   marks a query with an error ERROR and a query with a timeout INCONCLUSIVE, and exits 1 on any
   error.

The trigger detection follows upstream run_single_query (revision 683bc88): the first tool_use
block decides. A Skill or Read call that names the temporary command is a trigger; any other tool,
or a message with no tool call, is "not triggered".

Run from run_trigger.sh: PYTHONPATH=<skill-creator>:<this folder> python3 -c "import trigger_shim; trigger_shim.main()" ...
"""
from __future__ import annotations

import json
import os
import select
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

CLAUDE = "claude"  # tests point this at a fake CLI


class Detector:
    """Feed stream-json events in order. feed() returns None until the outcome is known, then
    ("success", triggered, "") or ("error", False, detail)."""

    def __init__(self, clean_name: str):
        self.clean_name = clean_name
        self.pending_tool = None
        self.accumulated = ""

    def feed(self, event: dict):
        kind = event.get("type")
        if kind == "stream_event":
            se = event.get("event") or {}
            se_type = se.get("type", "")
            if se_type == "content_block_start":
                cb = se.get("content_block") or {}
                if cb.get("type") == "tool_use":
                    if cb.get("name", "") in ("Skill", "Read"):
                        self.pending_tool = cb.get("name")
                        self.accumulated = ""
                    else:
                        return ("success", False, "")
            elif se_type == "content_block_delta" and self.pending_tool:
                delta = se.get("delta") or {}
                if delta.get("type") == "input_json_delta":
                    self.accumulated += delta.get("partial_json", "")
                    if self.clean_name in self.accumulated:
                        return ("success", True, "")
            elif se_type in ("content_block_stop", "message_stop"):
                if self.pending_tool:
                    return ("success", self.clean_name in self.accumulated, "")
                if se_type == "message_stop":
                    return ("success", False, "")
        elif kind == "assistant":
            if event.get("error"):
                return ("error", False, f"assistant error: {event.get('error')}")
            for item in (event.get("message") or {}).get("content") or []:
                if not isinstance(item, dict) or item.get("type") != "tool_use":
                    continue
                name, inp = item.get("name", ""), item.get("input") or {}
                hit = ((name == "Skill" and self.clean_name in str(inp.get("skill", "")))
                       or (name == "Read" and self.clean_name in str(inp.get("file_path", ""))))
                return ("success", hit, "")
        elif kind == "result":
            if event.get("is_error"):
                return ("error", False, f"result is_error; subtype={event.get('subtype')}; "
                                        f"terminal_reason={event.get('terminal_reason')}")
            return ("success", False, "")
        return None


def classify(query: str, skill_name: str, skill_description: str, timeout: int, project_root: str,
             model: str | None = None) -> tuple[str, bool, str]:
    """Run one query in its own project folder. Return (outcome, triggered, detail)."""
    own = tempfile.mkdtemp(prefix="q-", dir=project_root)
    try:
        clean_name = f"{skill_name}-skill-{uuid.uuid4().hex[:8]}"
        commands = Path(own) / ".claude" / "commands"
        commands.mkdir(parents=True)
        indented = "\n  ".join(skill_description.split("\n"))
        (commands / f"{clean_name}.md").write_text(
            f"---\ndescription: |\n  {indented}\n---\n\n# {skill_name}\n\n"
            f"This skill handles: {skill_description}\n")
        cmd = [CLAUDE, "-p", query, "--output-format", "stream-json", "--verbose",
               "--include-partial-messages"]
        if model:
            cmd += ["--model", model]
        env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}
        try:
            proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                    cwd=own, env=env)
        except OSError as e:
            return ("error", False, f"could not start {CLAUDE}: {e}")
        det = Detector(clean_name)
        buf = b""
        start = time.time()
        try:
            while True:
                left = timeout - (time.time() - start)
                if left <= 0:
                    return ("timeout", False, f"no decision in {timeout}s")
                ready, _, _ = select.select([proc.stdout], [], [], min(1.0, left))
                if not ready:
                    continue
                chunk = os.read(proc.stdout.fileno(), 8192)
                eof = not chunk
                buf += chunk
                lines = buf.split(b"\n")
                buf = b"" if eof else lines.pop()
                for raw in lines:
                    try:
                        event = json.loads(raw.decode("utf-8", errors="replace"))
                    except json.JSONDecodeError:
                        continue
                    if isinstance(event, dict):
                        decision = det.feed(event)
                        if decision:
                            return decision
                if eof:
                    try:
                        code = proc.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        code = None
                    return ("error", False, f"exit {code} before any trigger decision")
        finally:
            if proc.poll() is None:
                proc.kill()
            proc.wait()
            if proc.stdout:
                proc.stdout.close()
    finally:
        shutil.rmtree(own, ignore_errors=True)


def run_single_query(query, skill_name, skill_description, timeout, project_root, model=None):
    """Drop-in for upstream run_single_query. Returns True only for a successful trigger; the
    outcome log tells run_trigger.sh which False results were failed calls."""
    try:
        outcome, triggered, detail = classify(query, skill_name, skill_description, timeout,
                                              project_root, model)
    except Exception as e:  # never let a crash read as "not triggered"
        outcome, triggered, detail = "error", False, f"shim exception: {e!r}"
    log = os.environ.get("COORD_TRIGGER_OUTCOME_LOG")
    if log:
        with open(log, "a", encoding="utf-8") as f:
            f.write(json.dumps({"query": query, "outcome": outcome, "triggered": triggered,
                                "detail": detail}) + "\n")
    if outcome != "success":
        print(f"{outcome.upper()}: {detail}: {query[:70]}", file=sys.stderr)
    return outcome == "success" and triggered


def main():
    if not os.environ.get("COORD_TRIGGER_OUTCOME_LOG"):
        print("trigger_shim: set COORD_TRIGGER_OUTCOME_LOG; without it a failed call reads as "
              "'not triggered'", file=sys.stderr)
        sys.exit(2)
    import scripts.run_eval as upstream
    upstream.run_single_query = run_single_query
    upstream.main()
