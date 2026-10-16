I'll do this, with one change: I'll try to get lint and typecheck running before the push, instead of relying only on CI. I'll still push if I can't.

**1. Verify the worktree (`~/wt/console-77`)**
- Print `pwd`, the toplevel, the branch and `HEAD`. Confirm they match PR #77's head branch, and stop if they don't.
- Run `git diff` to confirm the change is only the `await` and the `async` on the callback near `src/hooks/useSync.ts:42`, with nothing else mixed in.
- Re-fetch PR #77. It should still be open, the thread unresolved and the remote head unchanged. If someone else pushed, I'll `git pull --ff-only` first.

**2. Run the checks without the broken `node_modules`**
You couldn't run eslint or tsc, and that is the one risk here. Making a callback `async` often causes new errors:
- `@typescript-eslint/no-misused-promises`, if the callback is passed where a void return is expected.
- A Promise returned from a `useEffect` callback, if the callback is one.
- A rejected `refresh()` that nobody handles.

So I'd try these in order:
- Install in a throwaway clean checkout of the branch, in the scratchpad. I'd use `pnpm install --frozen-lockfile --ignore-scripts`, because the failing native dep is probably a postinstall build that eslint and tsc don't need. Then I'd run the repo's lint and `tsc --noEmit` on the changed file with the pinned versions.
- If that fails too, I'd read the call site by hand for the three risks above.
- If the checks still can't run, I'll push anyway. You've explicitly decided CI is the check for this change. I'd note in the PR and the thread reply that the change was not locally linted or typechecked, so a red CI is expected to be diagnosed rather than blindly rerun.

**3. Commit and push**
- Stage only `src/hooks/useSync.ts`.
- Commit with a message like `fix(useSync): await refresh() to satisfy no-floating-promises`. It ends with the required trailers:
  ```
  Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Tnnr75NBNLemXNHEJaoNPE
  ```
- Push to the PR branch as a normal push, not a force push.
- Re-query the remote to confirm the new head SHA.

**4. Reply on the thread**
- Run `scripts/pr-threads.sh` to see the current state, and check that codex's P1 is a real defect at `useSync.ts:42`. It is: `refresh()` is a floating promise.
- Reply through REST, not GraphQL, with the agent marker. The reply gives the fix commit SHA, says what changed (`await` plus an async callback), and says local lint and typecheck were not run, with CI as the check.
- I would not resolve the thread. A P1 that was a true finding and is now fixed isn't a bot false positive, so I'd leave resolution to the reviewer or the bot's re-review.

**5. Follow up**
- Watch the lint and typecheck jobs on the new head. If either fails, I'd read the diagnostic first and fix the cause before pushing again.
- Re-check READY with `ready.sh` on the new head. Codex's review needs to cover that head, and no thread should be left unanswered.
- Record the broken `pnpm install` in `~/wt/console-77` as a separate task, so it doesn't block the next person.