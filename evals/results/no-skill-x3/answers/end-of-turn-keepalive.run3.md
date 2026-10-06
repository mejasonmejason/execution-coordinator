Here's what I'd do. Having merge authority doesn't mean merging before CI finishes or before Dana reviews, so I'd only merge when the checks and the review say it's safe.

**1. Check current state (read-only)**
- Run `gh pr view` / `gh pr checks` on #88, #90 and #91 to confirm CI status, review state, and whether any have merge conflicts.
- Check whether the repo has auto-merge enabled and which checks and reviews branch protection requires.

**2. #88 and #90 (CI running)**
- If auto-merge is available and e2e is a required check, I'd run `gh pr merge <n> --auto --squash` on each, using whatever merge method the repo normally uses. GitHub then merges each one only if CI goes green, and nothing merges if it fails.
- If auto-merge isn't enabled, I wouldn't merge anything blind. I'd leave both PRs as they are and note that they're ready to merge once CI passes.
- I can't stay running overnight to watch CI, so auto-merge is the only way these land without you.

**3. #91 (waiting on Dana)**
- I would not merge it or enable auto-merge, unless branch protection actually requires an approving review. Otherwise auto-merge could land it as soon as CI passes, with no review from Dana.
- I wouldn't ping Dana or post comments. She's already been asked, and a late-night nudge isn't something you asked for.

**4. Handoff note**
I'd leave you a short summary like this:

- **#88:** auto-merge enabled, will merge when e2e passes (or: CI running, not queued, because auto-merge is off).
- **#90:** same as #88.
- **#91:** untouched, waiting on Dana's review. Merge it once she approves and CI is green.
- **Failures:** if CI fails on #88 or #90, auto-merge will simply not fire. Check in the morning.

I haven't run any of this yet. Say so if you'd rather I skip auto-merge and just leave all three untouched.