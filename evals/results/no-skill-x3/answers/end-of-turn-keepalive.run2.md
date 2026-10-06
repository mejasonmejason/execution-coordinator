Here's what I'd do. Having merge authority doesn't mean merging before the gates clear, so I'll keep CI and review as conditions.

**1. Check current state (read-only)**
- Run `gh pr checks` and `gh pr view` on acme/web#88, #90 and #91 to see CI status, review state, mergeability and conflicts.

**2. #88 and #90 (CI running)**
- I won't merge while e2e is pending. I'll poll with `gh pr checks --watch` (about 40 min).
- If all required checks pass and there are no conflicts or blocking reviews, I'll merge using the repo's usual merge method.
- If #88 merges first, I'll re-check #90 for conflicts or a stale base before merging it. If it needs a rebase, I'll rebase and wait for CI again, since the earlier green result no longer applies.
- If a check fails, I won't merge or retry blindly. I'll pull the failing job's logs, work out whether it's a real failure or a flake, and note it for you. I'll only re-run once if it's clearly a flake.

**3. #91 (waiting on Dana's review)**
- I won't merge it. Dana is on PST, so the review probably won't land tonight, and your merge authority doesn't extend to skipping a review. I won't bypass branch protection or use admin override.
- If Dana approves and CI is green while I'm still running, I'll merge it. Otherwise it stays open.

**4. Handoff**
- I'll write a short summary to the scratchpad, `status.md`, covering:
  - what merged (with SHAs)
  - what's still open and why
  - any failures, with log links
  - next steps, such as "#91 needs Dana's approval, then merge"
- I won't comment on PRs or ping Dana unless you ask, since that's outward-facing.

**Caveat:** I can only act while this session is alive. If it ends before e2e finishes, #88 and #90 will simply stay open and unmerged, which is safe. The summary will say where things stand either way.

Go ahead and log off. I'll leave #91 for Dana and merge #88 and #90 only if they come back green.