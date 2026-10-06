# PR inventory, routing and feedback

Read this when you discover the open PR portfolio (at start and on every sweep), read one PR's deep state, send a message to a PR's owner, follow a PR feedback procedure, refute a bot finding, audit review comments, or post a reply on a PR.

## Contents

- Discover PRs
- Deep state per PR
- Watch each PR
- Route a message to the owner
- Feedback procedures
- Refute bot findings
- Audit comments
- Reply through REST

## Discover PRs

Run both searches once per sweep. Bot-authored and hosted-agent PRs may be assigned to you rather than authored by you, so the second search is not optional.

```bash
# Your PRs and roster authors (repeated author: qualifiers are ORed), plus bot-authored PRs assigned to you
gh api -X GET search/issues --paginate -f per_page=100 \
  -f q='is:pr is:open archived:false author:@me author:<teammate>' \
  --jq '.items[] | [.html_url, .title, .updated_at, .draft] | @tsv'
gh api -X GET search/issues --paginate -f per_page=100 \
  -f q='is:pr is:open archived:false assignee:@me -author:@me' \
  --jq '.items[] | [.html_url, .title, .updated_at] | @tsv'
```

- Test discovery against each new class of PR before you trust a zero result, because a search that misses a class also returns zero.
- Get details from `gh pr view` or GraphQL, not from more searches, because the search API has a tighter rate limit.
- On a 403 `secondary rate limit`, back off for at least 2 minutes and continue from the ledger. This is the one 403 worth retrying.
- Claude Code cloud sessions refuse both searches and `gh pr view`. Use `gh api 'repos/O/R/pulls?state=open'` and `gh api repos/O/R/pulls/N` there.

## Deep state per PR

```bash
gh pr view <url> --json headRefOid,baseRefName,mergeable,reviewDecision,statusCheckRollup,isDraft
```

## Watch each PR

Each PR has one watcher. Prefer L3 events. Otherwise check threads and checks on each sweep.

- An unchanged `updatedAt` never excuses a missing required check or comment audit, because new checks and comments do not always change it.
- Never run duplicate `gh pr checks --watch` loops, because they burn rate limit and report the same thing twice.

## Route a message to the owner

| Owner | Command |
|---|---|
| Terminal session | `tmux send-keys -t <session> "<message>" Enter` |
| Headless Claude Code | `claude --resume <id> -p "<message>"` |
| Headless Codex | `codex exec resume <id> "<message>"` |
| Claude Code cloud session | `send_message` |
| Hosted PR-comment agent | a PR comment that triggers it, for example `@claude` |

Every message includes the PR, the head SHA, the check and thread URLs, and the task. If no owner is live, dispatch a new one or make the coordination-sized fix yourself.

## Feedback procedures

These complement the PR feedback rules in SKILL.md.

- **Author context.** User comments take priority. Comments on your own PR are plan items.
- **Sensitive changes.** Auth, security and CI pushes need a ledger ruling and a fresh-context review, not new user approval. Report any `APPROVED` review the push may have dismissed.
- **After pushing,** do not re-apply a thread's change. Track the new head and reply.
- **Posting automations** run dry until several runs agree with `scripts/pr-threads.sh`, because a wrong automation posts to real reviewers.
- **Failing checks.** Read `gh run view <run-id> --log-failed`, fix, and push once. Failures in shared setup (runner, dependency fetch) are infrastructure flakes: run `gh run rerun <run-id> --failed` and do not edit code.
- **Combine findings.** Merge the current-head AI findings with each reviewer's latest summary. Deduplicate them. Agreement between reviewers sets priority but is not proof. Refute each as below. False positives without a stated reason stay open.
- **Hard comments.** Get advisor analysis before you implement feedback on architecture, cross-service behavior, concurrency, performance or domain correctness.

## Refute bot findings

Treat an AI or bot finding as false unless a `file:line` proves a defect. Reject it with evidence when it is one of these:

- style that the linter already enforces;
- a null that the type or the caller already excludes;
- a race with no shared mutable path;
- a code snippet that does not compile;
- a comment on unchanged lines;
- a pre-existing issue (open a task for it);
- a change the PR states is intentional;
- a duplicate that is already answered.

Fix verified defects and explicit requirements. Never dismiss human comments this way, because a human reviewer's concern needs a human answer.

## Audit comments

Run `scripts/pr-threads.sh <pr-url> [...]` before PR reports, READY, handoffs and any claim that a comment is answered. Do not rely on memory, because threads change while you work.

| Row | Meaning | What to do |
|---|---|---|
| ACTION | An unresolved thread, PR comment or review summary with no agent reply after it | Fix it, reply with evidence, or ask a named human. |
| AWAITING | Unresolved, and the agent replied last | Not done; wait for the reviewer. |
| UNSENT | Your own PENDING review, which nobody else can see | Publish it or delete it. |
| INFO | A bot notice with no review content, such as "reached your usage limits" | No reply needed. Report it: the reviewer is silent, so the PR is still unreviewed by that reviewer. |

- INFO rows come from `$COORD_NOTICE_PATTERNS`, a `|`-separated list of `login:regex` pairs (login may be `*`). The default matches the Codex quota notice. An empty value turns the default off.
- Exit 1 means something is actionable. Exit 3 means a PR was unreadable, and is never treated as zero.
- When the user links a comment, answer it, re-audit, and handle the other ACTION rows in the same turn.
- Report the linked counts: `N need a response, M awaiting reviewer, K unsent`.

## Reply through REST

Reply through REST only:

```bash
export AGENT_MARKER="${AGENT_MARKER:-🤖 agent reply}"
gh api -X POST repos/OWNER/REPO/pulls/N/comments/COMMENT_ID/replies \
  -f body="$(printf '%s\n\n%s' "<reply>" "$AGENT_MARKER")"
```

- Use one fixed marker for every post and audit, because a shared login proves nothing about who replied.
- `AGENT_MARKER` may be the environment's fixed attribution footer. Keep any other footer the environment requires.
- Marker values are `|`-separated. `pr-threads.sh` defaults to `🤖|Generated by [Claude Code]`.
- Never use GraphQL review-reply mutations, because they create pending reviews that nobody else sees.
- Re-audit after posting until there are 0 UNSENT.
- Reply or fix within 10 minutes of seeing a user comment, and within 30 minutes for bot findings.
