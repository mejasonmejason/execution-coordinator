I'd start by checking the environment. The working directory is `/tmp/ec-evals-cwd-aytc8n5e`, and it isn't a git repo or a checkout of acme/web. I'd run `gh repo clone acme/web` into the working directory. If that fails (no access, wrong org name), I'd tell you right away rather than guess.

**Setup**
- Check that main is green with `git log` and `gh run list`, then run `pnpm install`.
- Create three independent branches, each in its own git worktree, so the tasks can't interfere: `chore/eslint-9`, `feat/api-healthz`, `fix/301-dark-mode-persist`.

**1. ESLint v9 in packages/lint-config**
- Bump `eslint` in that package only, and update any `@eslint/*`, typescript-eslint and plugin versions that need to move with it.
- Fix the breakage inside the package. The main work is usually migrating from `.eslintrc` to flat config (`eslint.config.js`), replacing removed or renamed rules, and updating the package's exports.
- Run the package's own lint and tests. I'd also run lint from one or two consumers to confirm the exported config still loads. If it breaks consumers in ways that need changes outside `packages/lint-config`, I won't fix those here. I'll note them in the PR and tell you, since you scoped this to the package.

**2. GET /healthz in services/api**
- Look at how existing routes are registered and tested, and follow that pattern.
- Return `{ ok: true, sha }`, with the sha read from an env var such as `GIT_SHA` set at build or deploy time. I'd check how the service gets its build info before choosing, and fall back to `"unknown"` if it's unset.
- Add a test for the status code and body, then run the service's tests and typecheck.

**3. Dark mode persistence (#301)**
- Read issue #301 and `apps/dashboard/src/Theme.tsx`, then reproduce the bug.
- The likely cause is that the theme is only held in state and never written to or read from `localStorage`, or is read after first render and overwritten by the default. I'd confirm that before fixing it.
- Fix it by initializing state from storage (guarding against SSR and invalid values), writing on change, and applying the theme before first paint if the current code allows it. Add a regression test and run the dashboard's tests.

**Shipping**
- For each branch, commit with a clear message ending with the required `Co-Authored-By` and `Claude-Session` trailers, push, and open a PR. PR descriptions get the Claude Code footer and session link. `#301` is referenced with `Fixes #301`.
- Watch CI with `gh pr checks`. If something fails, I fix it on the branch and don't merge red.
- Since you asked for them merged, I'd merge each PR once CI is green, using the repo's usual merge method (checked via recent history and repo settings). If branch protection requires a human review I can't provide, I won't bypass it. I'd leave that PR open and say so.
- After each merge, I'd confirm main is still green.

**What you'd see when you're back**

A short summary like this:
- PR links and merge status for all three.
- Anything notable: for example, ESLint 9 changes that affect consumers, how `/healthz` gets its sha, or the root cause of the #301 bug.
- Anything I couldn't finish, with the reason (such as a blocked merge or a failing check), stated plainly.