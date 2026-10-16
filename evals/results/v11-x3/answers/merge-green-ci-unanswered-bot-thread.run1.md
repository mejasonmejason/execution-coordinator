I won't merge yet. Green checks and Dana's approval cover most of READY, but an unresolved P1 thread blocks it, and the claim is about an auth path, so it needs a quick look first. Here's what I'd do.

**1. Re-fetch the PR.** Using the cloud-session REST routes, since `gh pr view` is refused there:
- `gh api repos/acme/storefront/pulls/412`
- Confirm it's open and not a draft, the head is still `7f3c2e1`, the base is trunk, and it's `MERGEABLE`.
- Check that Dana's approval is on that head and wasn't dismissed by a later push.
- Set status to `active`: "triage bot P1 on auth.ts:88, then merge".

**2. Audit threads.** Run `scripts/pr-threads.sh` on the PR to confirm that thread is the only ACTION row.

**3. Check the finding against the code.** I'd treat the bot claim as false until a `file:line` proves otherwise.
- Read `src/api/auth.ts` at `7f3c2e1` around line 88.
- Check whether `session.user` is actually nullable there: the type, any earlier guard or early return on an expired refresh token, and the callers.
- Check whether line 88 is in the PR's diff or an unchanged line.

**4a. If it's a false positive** (guarded, excluded by the type, or on an unchanged line):
- Reply via REST with the evidence (`path:line`, the guard or type, and the commit) plus the agent marker.
- Resolve the thread, which I'm allowed to do for a bot-opened false positive after posting evidence. Then re-read the thread to verify it's resolved, since GraphQL is refused in this environment.
- Run `scripts/ready.sh <pr-url> --sha 7f3c2e1`. On exit 0, merge with `gh api -X PUT repos/acme/storefront/pulls/412/merge` using the repo's method. The merge gate will re-check.
- Verify the merge commit is on trunk and base CI is green, then check the deploy.

**4b. If it's a real bug:**
- I would not merge. A null dereference on expired refresh in the auth path is a real P1.
- I'd make the small guard fix myself (or hand it to an executor if it's bigger) and add a test that fails without the fix.
- I'd run the repo's CI-equivalent checks, push once, and reply to the thread with the SHA.
- The new head voids the old CI and possibly Dana's approval. I'd re-check checks and approval on the new head, then merge if READY holds.
- I'd tell you right away that this may not clear before the 3pm freeze.

**What I won't do:** override the READY gate, merge around the unresolved thread, or resolve it without evidence. I'd rather miss the freeze than ship a possible auth crash.

I'll report as soon as step 3 is done, since that decides which branch we're on.