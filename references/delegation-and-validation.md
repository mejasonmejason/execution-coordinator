# Delegation, placement, acceptance review and validation

Read this when you choose how to delegate, decide whether work runs locally or on a hosted agent, run heavy local work, change tests, run an acceptance review, or validate UI or deployments.

## Contents

- Delegation choices
- Local or hosted
- Memory check
- Hosted briefs
- Acceptance review in detail
- Test integrity
- Validate behavior, not only builds

## Delegation choices

These complement the fan-out rules in SKILL.md.

- **Pilot, then batch.** For repeated units (migrations, codemods, changes across N repos), accept one pilot before starting parallel work. If 2 of the first 3 batch units fail the same way, stop, fix the brief and resume. Accept each unit separately. This is a progress check, not a cap on parallel work.
- **Model routing.** Use the lowest capable tier. Upgrade under the two-failed-attempts rule.
- **High-stakes workers.** Consult a stronger advisor before choosing an approach, after repeated errors, and before reporting done.
- **Drift checks.** Use a read-only scout or advisor to check long-running writers for drift from the brief.
- **Mechanical or overnight work.** Use a hosted agent (see local or hosted below).
- **Do not delegate** edits under 5 minutes, work that needs live context, or a second watcher on a PR, because the handoff costs more than the work.
- **Visible sessions.** Use a visible session when the user wants to watch, when work runs over about an hour, or when it must outlive this session.
- **Repo rule files.** Keep AGENTS.md and CLAUDE.md as scoped repo or package rules with exact test commands, protected paths and links, not pasted docs.

## Local or hosted

Host the work when it needs any of these:

- heavy tooling: repo-wide lint, codegen, full test suites or large builds;
- only pushed inputs: a branch, PR, issue or brief;
- a second heavy job while one already runs locally;
- a machine that failed the memory check;
- survival through machine downtime.

Keep work local when it needs uncommitted state, local-only credentials or services, local browser journeys, or quick coordination actions. Record the placement on the task and the ledger.

## Memory check

Run this before heavy local work, and on each sweep while heavy local work runs.

```bash
# macOS
memory_pressure | tail -1; sysctl -n vm.swapusage
# Linux
free -m; vmstat 1 2 | tail -1
ps -axm -o pid,rss,etime,command | head -8   # macOS; on Linux: ps aux --sort=-rss | head -8
```

The check fails if free memory is under 30%, swap grew, or one tool uses more than 6 GB. On a failure:

- Host new heavy work, and start no heavy local job, because the machine is already near its limit.
- Kill only tools orphaned from live executors, because killing a live executor's tool loses its work.
- Validate only the changed packages locally.

## Hosted briefs

A hosted run cannot see your machine, so its brief carries everything:

- the HTTPS repo URL, the branch or PR, and pasted file contents (not local paths);
- the ledger issue link.

Record the run ID or URL on the task and the ledger. Send fixes to the same run or thread. Start a new run only for an independent task.

## Acceptance review in detail

The acceptance criteria and the risk floor are in SKILL.md. This is how the review runs.

- Reviewers work on the target repo without write tools, because a reviewer that can edit stops being independent.
- They verify each citation at the reviewed head with nearby quotes, and cover every file in the diff.
- Drop findings nobody can verify. Re-review files no reviewer covered.
- Verify that the child commits are on the branch, that the head descends from the dispatch base, and that the worktree is clean.
- For registries, routes, schemas, proto, flags, DI wiring or generated code, check every required sibling before READY, because a missing sibling breaks at runtime, not in review.
- In monorepos, validate the affected dependency-graph targets and record missing coverage.
- Before dispatch, check the acceptance criteria blind, against the original request only, so the criteria test what was asked rather than what was built.
- With no terminal report from the executor, the state is UNKNOWN. Resume or redispatch.
- In fix rounds, review the delta since the last reviewed head (READY records it). Do one full `base_sha..head` review before acceptance.
- After a stack or batch lands, review the combined cross-PR interfaces and shared files before the project is complete.

## Test integrity

SKILL.md forbids deleting, skipping, weakening or re-baselining tests or lint to get green. These rules make that check concrete:

- Explain every test change in the PR. Also explain each `scripts/ready.sh` warning about deleted tests or changed CI, test or lint config.
- For a bug fix, prove the test fails without the fix, then restore the fix.
- Record the failures already present at the dispatch base, so they are not blamed on the change.
- For auth, security, payments and data migrations, use an independent test writer who works from the spec and does not see the implementation, because a writer who sees the code tests what it does, not what it should do.
- Relaxed thresholds, comparisons or tolerances, downgraded checks and removed metrics all weaken gates. Justify each one in the PR.
- Keep a fixture that violates only each hard gate, so a broken gate shows up as a passing fixture.

## Validate behavior, not only builds

For web work, run real browser or Playwright journeys. Label mocks as mocks. A mock never replaces a required real sign-in, because it cannot prove the real path works.

**UI.** Write task scenarios from the diff. The executor's owner or an advisor reviews them; this adds no new user gate. Drive the real branch. If SSO is needed, set a `human-gate` naming who must sign in, and never expose credentials. Capture screenshots, console errors and failed requests. Screenshots alone do not prove success. Link the pass or fail evidence for each scenario. Turn reusable flows into tests. Test mobile widths for visual changes.

**Deployment.**

- Build the exact remote commit. Deploy changed services in dependency order.
- Verify rollouts and logs, the deployed journeys, and that state persists after a reload.
- With canaries, compare against the stable control and promote only on passing signals. On a failed canary, run the configured rollback, then re-verify.
- On a post-merge or post-deploy failure, record the commit range, isolate the culprit and create an owned fix task.
- For demo videos, pace them and inspect them before attaching them to the PR. Mark superseded videos stale. State what each video proves.
- Demo-only data and omitted dependencies cannot prove the real paths. Open a task for each validation gap.
