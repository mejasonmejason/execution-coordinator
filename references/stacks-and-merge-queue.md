# Merging: the READY script, reviews, stacks, queues and post-merge checks

Read this when you run `scripts/ready.sh` or the merge gate and need the detail, when you chase reviews, when you push, restack or merge a PR stack, when a merge-queue batch fails, or before you touch the next PR after a merge.

## Contents

- Repository reflex (L0)
- What `scripts/ready.sh` checks
- The merge gate and overrides
- Get reviews
- Stack invariants
- Merge order
- Merge-queue failures
- Post-merge and queue checks
- Remote writes

## Repository reflex (L0)

- Trunk has required status checks and required reviews. CODEOWNERS routes reviews.
- Use the merge queue when the repo has one. Otherwise use `gh pr merge --auto --squash` (or the repo's method) once merge authority is recorded.
- A hosted `@mention` fix agent (for example the Claude Code GitHub Action or Copilot) owns its own pushes. Local and cloud agents run `git pull --ff-only` before pushing, and never push while the bot works, because the two pushes collide.
- On a stack, auto-merge and fix bots run only on the bottom PR. Restacks and merges stay with the stack owner.

## What `scripts/ready.sh` checks

`scripts/ready.sh <pr-url> --sha <reported head> [--key <dispatch>] [--paths "a/**,b"]` uses REST where GraphQL is refused.

It blocks on:

- a closed or draft PR, or a head that is not the `--sha` you gave;
- conflicting, behind, unknown or blocked mergeability;
- a required check that is failing, missing or pending (`--allow-pending` permits pending);
- a latest review that requests changes;
- owed or unsent replies, or an audit it cannot read;
- changed files outside the owned `--paths`.

Branch protection and rulesets supply the required checks. If that list is unreadable, the script warns and counts every reported check as required.

It warns on failing non-required checks, deleted tests, changed CI, test or lint config, and a head that does not descend from the dispatch base.

## The merge gate and overrides

`hooks/claude-merge-gate.sh` is a PreToolUse hook for Claude Code and Codex. On `gh pr merge` or a REST merge, it runs `scripts/ready.sh` on the current head and fails closed. `--auto` permits pending checks. Other harnesses run `scripts/ready.sh` themselves before merging.

Override only a blocker you have verified is wrong: prefix the command with `COORD_READY_OVERRIDE="<reason>"`. The override is logged in `.coordinator/overrides.log`. Disclose it in your next report, because an undisclosed override hides a skipped gate.

## Get reviews

1. Request the code owners when CI is green.
2. After 4 working hours without review, post one concise PR comment with the change, the risk and the evidence.
3. After 1 working day, draft a chat nudge asking for approval. Chat to people is human-only, so name the target and await approval before it is sent.
4. Record each nudge on the task.

If a reviewer is overdue or overloaded, ask another CODEOWNER. Assign other ready work during review waits, so executors do not idle.

## Stack invariants

After a parent branch gets a push:

1. Fetch the canonical remotes and pause pushes to child branches.
2. Restack and push with the repo's stack tool. Use `--force-with-lease` only on branches you own, and never force push by hand, because a manual force push can overwrite someone else's commits.
3. Verify the remote parent ancestry and each PR's base and mergeability, and rerun CI on the current head. Local ancestry cannot prove stack health, because only the remote branches merge.
4. Propagate fixes made in a lower layer up the stack in the same round. Reply with the SHA and the PRs.

After a downstack merge, prune the merged entries from the stack. Where the repo requires signed commits, verify every rebased descendant is still signed before you push, because a rebase can drop signatures.

## Merge order

Merge stacks bottom-up. After each merge, retarget or restack the next PR onto the current trunk, wait for CI on the new base, and recheck the base. Never merge into a branch that is merged or about to merge, because those commits never reach trunk.

## Merge-queue failures

When batch checks fail, isolate the culprit by queue bisection or subset runs. Requeue the passing PRs and retest them on the new base. Incident, security and unblocker PRs may jump the queue; record why. The checks themselves never change to let a batch through.

## Post-merge and queue checks

- Before you touch the next PR, confirm the merged commits are on trunk. Before the next merge into a base, confirm the merge commit is there and the base CI is green. Red or unknown base CI stops all merges and becomes the top task, because every later merge would build on a broken base.
- Regularly reconcile actual merges against the recorded READY verdicts and overrides. A merge of ours with no passing READY at its merged head and no logged override is an anomaly; record it as a lesson.
- Before acting on a queue dequeue or failure event, compare the event's SHA with the current PR head, because the event may describe an older head.
- Verify running values, not files on disk. Never restart siblings you did not touch, because a restart is a production change nobody asked for.
- If the runtime shows a wrong value or target, find the cause (target, cache or reload) before you redeploy or restart, because a blind restart can hide it.
- After every mutating remote command, verify its target, even when the command failed, because a failed command can still have partly applied.

## Remote writes

- Read back every configuration or launch change (job or session name, model, advisor, hook), because fields can drop silently.
- Make writes idempotent: use stable IDs and check before you write, because a retried write must not apply twice.
- Before a cross-system change that can partly commit, record the repair steps.
