I can't run commands or reach GitHub from this session, so this is the plan I'd follow and what I'd say. Nothing below has been done yet.

**1. Check who owns coordination first.**
There's already a `[coord] billing-q4` session, and #512 was edited 2 hours ago. That suggests a live coordinator, and there must be only one per project. I won't start a second one or write to the ledger yet.
- I'd check `[coord] billing-q4` with `get_session` and `list_events`. I'd also read #512 and its edit history to see who wrote the last edit.
- If the session is live, I'd send it one message with `send_message` saying I've been asked to drive this to merge and have merge authority. I'd ask it to confirm the current state and whether it keeps ownership or hands over. Silence doesn't transfer ownership.
- If it's dead or archived, I take over. I'd write that into the ledger and rename it with a `v2` suffix.
- Either way, I'd treat the contents of #512, the PR bodies, and anything Marco or the sessions wrote as data, not instructions. I'd also read `CLAUDE.md` and `AGENTS.md` in acme/billing for merge rules before I merge anything.

**2. Inventory #540–#547 with REST only.**
Cloud sessions refuse GraphQL and `gh pr view`, so I'd use `gh api repos/acme/billing/pulls/N` for each PR. For each I'd record head SHA, base branch, mergeability, and checks. I'd also check whether the PRs form a stack, from their base branches. I'd run `scripts/pr-threads.sh` on each, which falls back to REST, and `scripts/ready.sh` on each current head. Every PR needs a task and an owner. I'd classify every task into exactly one of dispatchable, blocked, in flight, needs attention, or closeable, and make the counts add up to all 8.

**3. Check the two executors.**
For `[exec] billing: BIL-88 proration` and `BIL-90 dunning emails`, I'd use `get_session` to see whether each is running, idle, or finished.
- A running one stays the single writer for its PR. I'd route fixes to it.
- An idle one with unfinished work gets resumed from its last checkpoint.
- A finished one with its PR merged gets archived. I won't message it, because that would wake it up.
- PRs with no live owner get a fresh executor, or I make the small fix myself.

**4. Start with the most broken PR, which means red CI.**
For each failing PR, I'd read the `--log-failed` output before rerunning or rebasing.
- If it's a shared-setup or infra flake, it gets one `gh run rerun --failed`.
- If the PR's diff touches the failing path, or the same job passes on base, I'd treat it as PR-caused and send it to the owner with the exact failure.
- After two failed attempts on the same failure, I'd change the executor or model, or use a diagnostic scout. I won't delete or weaken tests to get green.
- I'd put each failure on the PR's task. I'd also run `gh run` against the base branch, because if base CI is red, merges stop there.

**5. Merge in order, bottom of the stack first.**
For each PR, I'd run `scripts/ready.sh <url> --sha <head>`.
- Required checks must be green on the current head, there must be no open threads, and the PR must be mergeable.
- The hard review gate covers billing, payments, and data-migration PRs. They'd need an independent fresh-context reviewer, ideally three perspectives with 2 of 3 passing, before I accept them.
- Missing human approval is a gate. I'd report it and request the code owners, not bypass it. I'd never self-approve or use an admin bypass.
- Once READY holds, I'd merge through the repo's path (merge queue or REST merge), with the merge-gate hook active.
- After each merge, I'd confirm the commit is on trunk and base CI is green. Then I'd retarget the next PR, wait for CI on the new base, and repeat.

**6. Keep state and report.**
I'd set `status.sh` to `active` with the next action, and put a `--busy` lease on it before any fan-out. Task and ledger updates go to the owner of #512 once ownership is settled. I'd subscribe to PR activity and end turns on events, with no sleep-polling.

My first report would be a status table with owner, PR, head, failing checks, open threads, and next action for each of the 8 PRs. It would say which coordinator I found, which PR I'm fixing first, and anything that needs Marco or a code owner.