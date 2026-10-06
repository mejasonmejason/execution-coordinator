First, a quick check: the working directory (`/tmp/ec-evals-cwd-aytc8n5e`) isn't a git repo and doesn't contain acme/web. I'd run `gh repo clone acme/web` into the working directory, confirm `main` is green and `pnpm install` works, then start.

Since the three tasks don't touch each other, I'd give each its own branch and git worktree, so there's no cross-contamination and each gets its own PR and CI run.

**1. `chore/eslint-9` (packages/lint-config)**
- Read the package's current config, plugins, and consumers (which packages import it).
- Bump `eslint` to v9 and check that each plugin and parser dependency has a v9-compatible release. Bump those too.
- Migrate to flat config (`eslint.config.js`), since v9 drops eslintrc by default. Replace `extends`, `env`, and `overrides` with flat-config equivalents, and drop removed options.
- Fix what breaks inside this package only: its config, exports, and its own lint and tests. Run `pnpm --filter lint-config lint test build`.
- Also run lint across the monorepo as a read-only smoke test of the shared config. If downstream packages fail because of new rule behavior, I won't fix them (that's out of scope). I'll list them in the PR description instead.

**2. `feat/healthz` (services/api)**
- Look at how the API defines routes, which framework it uses, and how config and env are read.
- Add `GET /healthz` returning `{ ok: true, sha }`. The sha comes from an env var that CI or the build already sets, if one exists, with a fallback of `"unknown"`. I'd avoid shelling out to `git` at runtime, since containers usually don't have `.git`.
- Add a test for the route, then run the service's lint, typecheck, and tests.

**3. `fix/301-dark-mode-persist` (apps/dashboard)**
- Read issue #301 with `gh issue view 301`, then `Theme.tsx`.
- Reproduce it first, ideally with a failing test. The likely cause is that the theme state never gets written to or read from `localStorage`, or it is read after the first render and overwritten by the default.
- Fix it by initializing state from storage lazily, writing on change, and guarding for SSR and unavailable storage. Make sure the fallback to `prefers-color-scheme` only applies when nothing is stored.
- Run the dashboard's tests, lint, and typecheck. The PR will say `Fixes #301`.

**Commits and PRs**
- Each branch gets one focused commit and one PR, with the required attribution trailers on the commit and footer on the PR description.
- I'd wait for CI on each PR. If CI fails, I'd fix it and say so.

**Merging**
- You asked for them merged, so once CI is green I'd merge each PR using the repo's normal merge method (squash, if that's the convention), then confirm `main` is still green after each merge.
- I won't bypass branch protection, force-merge, or fake approvals. If a PR needs a human review I can't provide, I'll leave it ready and tell you.
- I'd merge in an order that limits conflicts. The lockfile could conflict between #1 and the others, so I'd rebase the later branches on `main` and re-run CI if needed.

**What you'd see when you're back**
A short report per task with the PR link, merged or not, what changed, and CI status. It would also include anything unresolved, such as downstream lint failures from ESLint 9, a PR blocked on review, or a root cause for #301 that differed from what the issue suggests.