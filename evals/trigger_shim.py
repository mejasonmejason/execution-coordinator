"""Wrapper around skill-creator's scripts/run_eval.py (imported from the local checkout, not vendored).

It changes two things and keeps everything else, including how a trigger is detected:

1. One project folder per query. Upstream run_eval.py writes every worker's temporary command file
   into one shared <project>/.claude/commands folder. With more than one worker, each `claude -p`
   then sees several copies of the skill (one per worker, each with its own uuid) and often picks
   another worker's copy, which counts as "not triggered". Measured 2026-10-06 with 5 workers: a
   query that triggered 3 of 4 times on its own scored 0 of 3. Here each call gets its own folder.
2. Timeouts are recorded. Upstream returns "not triggered" on a timeout, which would score as a
   pass for a should-not-trigger query. Each timeout is appended to $COORD_TRIGGER_TIMEOUT_LOG so
   run_trigger.sh can mark that query INCONCLUSIVE instead.

Run from run_trigger.sh: PYTHONPATH=<skill-creator>:<this folder> python3 -c "import trigger_shim; trigger_shim.main()" ...
"""
import os
import shutil
import sys
import tempfile
import time

import scripts.run_eval as upstream

_original = upstream.run_single_query


def run_single_query(query, skill_name, skill_description, timeout, project_root, model=None):
    own = tempfile.mkdtemp(prefix="q-", dir=project_root)
    os.mkdir(os.path.join(own, ".claude"))
    start = time.time()
    try:
        triggered = _original(query, skill_name, skill_description, timeout, own, model)
    finally:
        shutil.rmtree(own, ignore_errors=True)
    if not triggered and time.time() - start >= timeout - 1:
        log = os.environ.get("COORD_TRIGGER_TIMEOUT_LOG")
        if log:
            with open(log, "a", encoding="utf-8") as f:
                f.write(query.replace("\n", " ") + "\n")
        print(f"TIMEOUT after {timeout}s: {query[:70]}", file=sys.stderr)
    return triggered


upstream.run_single_query = run_single_query


def main():
    upstream.main()
