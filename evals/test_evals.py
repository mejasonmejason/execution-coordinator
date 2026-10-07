"""Offline tests for the eval runners (issue #24). No model calls.

Run: python3 -m pytest evals   or   python3 evals/test_evals.py
"""
from __future__ import annotations

import json
import os
import stat
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import run_behavior as rb  # noqa: E402
import trigger_grade as tg  # noqa: E402
import trigger_shim as shim  # noqa: E402


def fake_claude(lines: list[dict], exit_code: int = 0, sleep: float = 0.0) -> str:
    """Write a fake `claude` that prints these stream-json events and exits. Returns its path.
    A "{CLEAN}" in an event is replaced with the command name the shim created in .claude/commands."""
    d = tempfile.mkdtemp(prefix="fake-claude-")
    path = os.path.join(d, "claude")
    body = json.dumps([json.dumps(e) for e in lines])
    Path(path).write_text(f"""#!{sys.executable}
import glob, json, os, sys, time
time.sleep({sleep})
names = [os.path.basename(p)[:-3] for p in glob.glob(".claude/commands/*.md")]
clean = names[0] if names else "none"
for line in json.loads({body!r}):
    print(line.replace("{{CLEAN}}", clean), flush=True)
sys.exit({exit_code})
""")
    os.chmod(path, os.stat(path).st_mode | stat.S_IEXEC)
    return path


def run_shim(lines, exit_code=0, timeout=20, sleep=0.0):
    old = shim.CLAUDE
    shim.CLAUDE = fake_claude(lines, exit_code, sleep)
    proj = tempfile.mkdtemp(prefix="proj-")
    try:
        return shim.classify("q", "ec", "desc", timeout, proj)
    finally:
        shim.CLAUDE = old


def se(event: dict) -> dict:
    return {"type": "stream_event", "event": event}


class ShimOutcome(unittest.TestCase):
    def test_fast_model_error_is_error_not_untriggered(self):
        # The shape `claude -p --model no-such-model` printed on 2026-10-07: exits in ~1s.
        out = run_shim([{"type": "assistant", "error": "model_not_found",
                         "message": {"content": [{"type": "text", "text": "There's an issue"}]}},
                        {"type": "result", "subtype": "success", "is_error": True,
                         "terminal_reason": "api_error"}], exit_code=1)
        self.assertEqual(out[0], "error")
        self.assertFalse(out[1])

    def test_result_is_error_is_error(self):
        out = run_shim([{"type": "result", "subtype": "success", "is_error": True}], exit_code=1)
        self.assertEqual(out[0], "error")

    def test_exit_without_output_is_error(self):
        out = run_shim([], exit_code=1)
        self.assertEqual(out[0], "error")
        self.assertIn("exit 1", out[2])

    def test_missing_cli_is_error(self):
        old = shim.CLAUDE
        shim.CLAUDE = "/nonexistent/claude"
        try:
            out = shim.classify("q", "ec", "desc", 5, tempfile.mkdtemp())
        finally:
            shim.CLAUDE = old
        self.assertEqual(out[0], "error")

    def test_timeout_is_timeout(self):
        out = run_shim([], sleep=10, timeout=1)
        self.assertEqual(out[0], "timeout")

    def test_trigger_via_skill_stream(self):
        out = run_shim([se({"type": "content_block_start", "content_block": {"type": "tool_use", "name": "Skill"}}),
                        se({"type": "content_block_delta",
                            "delta": {"type": "input_json_delta", "partial_json": '{"skill": "{CLEAN}"}'}})])
        self.assertEqual(out, ("success", True, ""))

    def test_other_tool_is_success_not_triggered(self):
        out = run_shim([se({"type": "content_block_start", "content_block": {"type": "tool_use", "name": "Bash"}})])
        self.assertEqual(out, ("success", False, ""))

    def test_plain_answer_is_success_not_triggered(self):
        out = run_shim([se({"type": "content_block_start", "content_block": {"type": "text"}}),
                        se({"type": "content_block_stop"}), se({"type": "message_stop"})])
        self.assertEqual(out, ("success", False, ""))

    def test_clean_result_is_success_not_triggered(self):
        out = run_shim([{"type": "assistant", "message": {"content": [{"type": "text", "text": "4"}]}},
                        {"type": "result", "subtype": "success", "is_error": False}])
        self.assertEqual(out, ("success", False, ""))

    def test_run_single_query_logs_outcome(self):
        log = os.path.join(tempfile.mkdtemp(), "outcomes.jsonl")
        old_env, old = os.environ.get("COORD_TRIGGER_OUTCOME_LOG"), shim.CLAUDE
        os.environ["COORD_TRIGGER_OUTCOME_LOG"] = log
        shim.CLAUDE = fake_claude([{"type": "result", "is_error": True}], 1)
        try:
            got = shim.run_single_query("what is 2+2", "ec", "desc", 10, tempfile.mkdtemp())
        finally:
            shim.CLAUDE = old
            if old_env is None:
                os.environ.pop("COORD_TRIGGER_OUTCOME_LOG")
            else:
                os.environ["COORD_TRIGGER_OUTCOME_LOG"] = old_env
        self.assertFalse(got)
        rec = json.loads(Path(log).read_text())
        self.assertEqual((rec["query"], rec["outcome"]), ("what is 2+2", "error"))


class TriggerGrade(unittest.TestCase):
    def results(self):
        return [{"query": "a", "should_trigger": False, "runs": 2, "triggers": 0, "pass": True},
                {"query": "b", "should_trigger": True, "runs": 2, "triggers": 2, "pass": True},
                {"query": "c", "should_trigger": False, "runs": 2, "triggers": 0, "pass": True},
                {"query": "d", "should_trigger": False, "runs": 2, "triggers": 0, "pass": True}]

    def test_errors_never_pass(self):
        rs = self.results()
        outs = {"a": [{"outcome": "error", "triggered": False}, {"outcome": "success", "triggered": False}],
                "b": [{"outcome": "success", "triggered": True}] * 2,
                "c": [{"outcome": "timeout", "triggered": False}, {"outcome": "success", "triggered": False}],
                "d": [{"outcome": "success", "triggered": False}]}  # one run has no outcome line
        tg.regrade(rs, outs)
        a, b, c, d = rs
        self.assertEqual((a["pass"], a.get("error"), a["errors"]), (False, True, 1))
        self.assertTrue(b["pass"])
        self.assertEqual((c["pass"], c.get("inconclusive"), c["timeouts"]), (False, True, 1))
        self.assertEqual((d["pass"], d.get("error"), d["errors"]), (False, True, 1))

    def test_main_exits_1_and_marks_invalid(self):
        tmp = Path(tempfile.mkdtemp())
        (tmp / "t.json").write_text(json.dumps({"description": "x", "results": self.results()[:2]}))
        (tmp / "o.jsonl").write_text("\n".join(json.dumps(o) for o in [
            {"query": "a", "outcome": "error", "triggered": False, "detail": "auth"},
            {"query": "a", "outcome": "error", "triggered": False, "detail": "auth"},
            {"query": "b", "outcome": "success", "triggered": True, "detail": ""},
            {"query": "b", "outcome": "success", "triggered": True, "detail": ""}]) + "\n")
        (tmp / "SKILL.md").write_text("x")
        code = tg.main([str(tmp / "t.json"), str(tmp / "s.md"), str(tmp / "SKILL.md"), "t", "1", "m", "2",
                        str(tmp / "o.jsonl"), "1"])
        self.assertEqual(code, 1)
        d = json.loads((tmp / "t.json").read_text())
        self.assertFalse(d["summary"]["valid"])
        self.assertEqual(d["summary"]["passed"], 1)
        self.assertTrue(d["meta"]["home_isolated"])
        self.assertIn("INVALID RUN", (tmp / "s.md").read_text())

    def test_main_clean_run_exits_0(self):
        tmp = Path(tempfile.mkdtemp())
        (tmp / "t.json").write_text(json.dumps({"description": "x", "results": self.results()[:2]}))
        (tmp / "o.jsonl").write_text("\n".join(json.dumps(o) for o in [
            {"query": "a", "outcome": "success", "triggered": False, "detail": ""},
            {"query": "a", "outcome": "success", "triggered": True, "detail": ""},
            {"query": "b", "outcome": "success", "triggered": True, "detail": ""},
            {"query": "b", "outcome": "success", "triggered": False, "detail": ""}]) + "\n")
        (tmp / "SKILL.md").write_text("x")
        code = tg.main([str(tmp / "t.json"), str(tmp / "s.md"), str(tmp / "SKILL.md"), "t", "1", "m", "2",
                        str(tmp / "o.jsonl"), "0"])
        self.assertEqual(code, 0)
        d = json.loads((tmp / "t.json").read_text())
        # a: 1/2 triggers on a should-not query fails (rate 0.5 is not < 0.5); b: 1/2 passes.
        self.assertEqual([r["pass"] for r in d["results"]], [False, True])
        self.assertFalse(d["meta"]["home_isolated"])


EXPS = ["The answer declines to receive the credentials.", "The answer names the exact command."]


def judge(*items) -> str:
    return "Here you go:\n" + json.dumps([{"assertion": a, "pass": p, "evidence": "e"} for a, p in items])


class GraderIdentity(unittest.TestCase):
    def test_matching_assertions_parse(self):
        g, why = rb.parse_grades(judge((EXPS[0], True), (EXPS[1], False)), EXPS)
        self.assertEqual([x["passed"] for x in g], [True, False])
        self.assertEqual(why, "")

    def test_loose_formatting_still_matches(self):
        g, _ = rb.parse_grades(judge(("1. the answer  declines to receive the credentials", True),
                                     ("2. The answer names the exact command", True)), EXPS)
        self.assertIsNotNone(g)

    def test_unrelated_assertion_is_rejected(self):
        g, why = rb.parse_grades(judge((EXPS[0], True), ("The answer is polite.", True)), EXPS)
        self.assertIsNone(g)
        self.assertIn("grade 2", why)

    def test_swapped_order_is_rejected(self):
        g, _ = rb.parse_grades(judge((EXPS[1], True), (EXPS[0], True)), EXPS)
        self.assertIsNone(g)

    def test_missing_assertion_field_is_rejected(self):
        text = json.dumps([{"pass": True, "evidence": "e"}, {"pass": True, "evidence": "e"}])
        self.assertIsNone(rb.parse_grades(text, EXPS)[0])

    def test_grade_turns_mismatch_into_grader_error(self):
        class FakeClaude:
            def ask(self, prompt, model=None):
                return {"status": "ok", "text": judge((EXPS[0], True), ("Something else.", True)), "detail": ""}
        g = rb.grade(FakeClaude(), None, "p", "answer", EXPS)
        self.assertEqual(g["status"], "unparsable")
        self.assertTrue(all(not x["passed"] and x["status"] == "grader_error" for x in g["expectations"]))
        self.assertIn("names another assertion", g["expectations"][0]["evidence"])


class HomeIsolation(unittest.TestCase):
    def test_isolated_by_default(self):
        self.assertTrue(_parse_args(["--no-skill", "--out", "x"]).isolate_home)
        self.assertFalse(_parse_args(["--no-skill", "--out", "x", "--no-isolate-home"]).isolate_home)
        self.assertTrue(_parse_args(["--no-skill", "--out", "x", "--isolate-home"]).isolate_home)

    def test_claude_env_home(self):
        c = rb.Claude(None, 1, 0, True)
        self.assertNotEqual(c.env.get("HOME"), os.environ.get("HOME"))
        self.assertNotIn("CLAUDE_CODE_SYNC_SKILLS", c.env)
        self.assertEqual(rb.Claude(None, 1, 0, False).env.get("HOME"), os.environ.get("HOME"))

    def test_summary_labels_non_isolated_run(self):
        r = {"summary": {"runs": 0, "goldens_caught": 0, "goldens": 0}, "skill_path": None,
             "started_utc": "s", "finished_utc": "f", "answer_model_requested": "m",
             "grader_model_requested": "m", "models_seen": [], "runs_per_eval": 1, "claude_calls": 0,
             "cost_usd_reported": 0, "evals": [], "goldens": [], "home_isolated": False}
        self.assertIn("HOME isolated: NO", rb.render_summary(r))


def _parse_args(argv):
    """Return the namespace run_behavior.main() parses for argv, and stop main() there."""
    captured = {}

    class Stop(Exception):
        pass

    orig = rb.argparse.ArgumentParser.parse_args

    def grab(self, args=None, namespace=None):
        captured["ns"] = orig(self, argv, namespace)
        raise Stop

    rb.argparse.ArgumentParser.parse_args = grab
    try:
        rb.main()
    except Stop:
        pass
    finally:
        rb.argparse.ArgumentParser.parse_args = orig
    return captured["ns"]


if __name__ == "__main__":
    unittest.main()
