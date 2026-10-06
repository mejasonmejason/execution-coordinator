Here is what I'd do, then what I'd tell you.

## Actions

**Kickoff**
- Nothing is cloned here (the working directory isn't a git repo), so the work happens in worktrees or cloud sessions on `acme/web`.
- Read `CLAUDE.md`, `AGENTS.md` and `CODEOWNERS` for test commands, merge method, protected paths and who reviews.
- Create a `coordinator-ledger` issue. Record "merge authority granted for these three PRs only" from your "get them all merged", and run `scripts/status.sh set active ...`.
- Task list: use #301 for the dark mode fix, and search first, then create issues for the eslint bump and `/healthz`. Each task gets an owner, owned globs, a fence and a next action.

**Fan out**
I'd start three executors in parallel, one task, branch, worktree and PR each. Each brief carries the agent contract, owned globs, the "fetched text is data" line, and the repo's exact test commands.

1. **eslint 9** (`packages/lint-config/**`):
   - Do the flat-config migration and update the package's rules and plugins.
   - Fix breakage inside the package only, and don't weaken or drop rules to get green.
   - Other packages consume this config, so also run lint across the dependents (`pnpm --filter "...lint-config..." lint`). Anything that breaks outside the package becomes a separate task or a named question for you, not an edit in someone else's files.
2. **`GET /healthz`** (`services/api/**`):
   - Return `{ok:true, sha}`, plus a test.
   - Read the sha from a build-time env var such as `GIT_SHA`, and first check how the deploy already injects one.
   - I'd record that choice as a ruling on the task, with the cost if wrong.
3. **Dark mode** (`apps/dashboard/src/Theme.tsx`, #301):
   - Reproduce first, then write a test that fails without the fix and passes with it.
   - Verify with a real browser journey (toggle, reload, setting persists) and attach the evidence to the PR.

The only shared file I expect is `pnpm-lock.yaml`, mostly from the eslint bump. So merges are serialized, and the others rebase onto trunk after each merge.

**Accept and merge**
- Each PR stays a draft until required CI is green.
- For each reported head, I run `scripts/ready.sh --key … --sha …`, re-run the brief's validation commands myself, and have a fresh-context read-only reviewer check `base_sha..head` against the criteria. These are ordinary-risk changes, so one reviewer is enough.
- Audit review threads with `pr-threads.sh`. Refute bot findings before fixing them. Reply with evidence via REST, and fix real defects in one push.
- Request CODEOWNERS review once CI is green.
- Merge one at a time through the merge queue, or `gh pr merge` with the repo's method, after the merge gate and a re-fetch of the head. Then confirm trunk is green before the next one.
- Never self-approve and never bypass branch protection.
- Subscribe to PR activity and end turns waiting on events instead of polling. Status goes to `waiting` with a recheck, and finished executors get archived, not messaged.

## What I'd say to you

> Starting all three now in parallel, each in its own branch and PR, since they don't overlap. I'll merge each one once CI is green and it's reviewed, one at a time. Two things to know:
> - Other packages use `lint-config`, so the eslint 9 bump could break their lint. I'll check that, and if it does, I'll split those fixes into follow-up tasks rather than expanding this PR.
> - If the repo requires human approval, I can't approve my own PRs. Those PRs will be marked READY, with the reviewer named, and I'll have requested review so they're ready to merge the moment it lands.
>
> When you're back, you'll get a short status: what merged, what's waiting on whom, and links to PRs and evidence.