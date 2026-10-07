# Visual overview

These diagrams show what the skill does. GitHub draws them from the Mermaid source below. `SKILL.md` and `references/` stay the source of truth; the labels use their heading names.

1. [What is in the skill](#1-what-is-in-the-skill)
2. [The four operating layers](#2-the-four-operating-layers)
3. [Lifecycle of one piece of work](#3-lifecycle-of-one-piece-of-work)
4. [Dispatch records](#4-dispatch-records)
5. [The merge gate](#5-the-merge-gate)
6. [Keep-alive](#6-keep-alive)
7. [Review-thread audit](#7-review-thread-audit)
8. [Claude Code and Codex](#8-claude-code-and-codex)

## 1. What is in the skill

`SKILL.md` holds the rules. The scripts enforce the rules that a program can check. The hooks connect the scripts to the agent, so the agent cannot skip them. All state is in one git-ignored file per worktree.

```mermaid
flowchart LR
  subgraph Rules["SKILL.md: the core loop"]
    R1["ledger and backlog"]
    R2["fence, plan, fan-out"]
    R3["READY and MERGE"]
    R4["dispatch and acceptance"]
    R5["events and sweep"]
    R6["status and replies"]
  end
  Refs["references/*.md<br/>detail read only when needed:<br/>cloud and Codex, keep-alive,<br/>PR inventory and feedback,<br/>delegation and validation,<br/>merging, lessons"]
  Rules -. "read when" .-> Refs
  subgraph Scripts["scripts/: checks a program can run"]
    S1["status.sh<br/>status, busy lease, dispatches"]
    S2["ready.sh<br/>READY check for one PR head"]
    S3["pr-threads.sh<br/>owed replies audit"]
  end
  subgraph Hooks["hooks/: run by the agent harness"]
    H1["claude-stop-hook.sh<br/>Stop event"]
    H2["claude-merge-gate.sh<br/>PreToolUse on Bash"]
    H3["session-start.sh<br/>SessionStart event"]
  end
  State[(".coordinator/status.json")]
  GH[("GitHub REST and GraphQL")]
  R3 --> S2
  R4 --> S1
  R6 --> S3
  R5 --> S1
  H2 --> S2
  S2 --> S3
  S1 <--> State
  H1 --> State
  H3 --> State
  S2 -- "--key records verdict" --> State
  S2 --> GH
  S3 --> GH
  T["tests/run.sh<br/>offline cases, stubbed gh"] -. tests .-> S1 & S2 & S3 & H1 & H2 & H3
```

## 2. The four operating layers

Each layer covers a time when the layer above it cannot act (see the layer table in `references/keepalive.md`).

```mermaid
flowchart TB
  L0["L0 Repository reflex<br/>branch protection, required checks,<br/>merge queue, CODEOWNERS<br/><i>always, seconds</i>"]
  L1["L1 Control tower<br/>this coordinator session,<br/>reacts to events<br/><i>while the session is live</i>"]
  L2["L2 Sweeper<br/>scheduled headless run,<br/>reconciles the ledger<br/><i>every 10 to 60 min</i>"]
  L3["L3 Event trigger<br/>GitHub Actions on reviews,<br/>comments, check suites<br/><i>seconds, when configured</i>"]
  L1 -- "session ends or stalls" --> L2
  L3 -- "wakes or pings" --> L1
  L0 -- "enforces gates for" --> L1
  L2 -- "nudges idle owners" --> L1
```

## 3. Lifecycle of one piece of work

The coordinator plans, sends independent tasks to executors in parallel, checks each claim of "done" itself, and merges only through the READY fence. A failure at any check sends the task back to its executor.

```mermaid
flowchart TD
  A["Objective"] --> B["Completion fence<br/>observable criteria"]
  B --> C["Dependency graph<br/>independent vs shared files"]
  C --> D{"Independent?"}
  D -- "yes" --> E["Fan out<br/>one executor, one worktree,<br/>one branch per task"]
  D -- "no, shared files" --> F["One writer,<br/>stack order"]
  E --> G["status.sh dispatch KEY<br/>records base_sha, paths, branch"]
  F --> G
  G --> H["Executor works,<br/>opens PR, reports done"]
  H --> I["dispatch --state awaiting-acceptance"]
  I --> J["Acceptance"]
  J --> J1["ready.sh --key KEY --sha HEAD"]
  J --> J2["Coordinator re-runs<br/>validation commands"]
  J --> J3["Fresh-context reviewer<br/>path:line per criterion"]
  J1 & J2 & J3 --> K{"All pass?"}
  K -- "no" --> L["dispatch --state rejected<br/>exact findings back to executor"]
  L --> H
  K -- "yes" --> M["dispatch --state accepted"]
  M --> N["MERGE<br/>re-fetch, merge gate, repo merge path"]
  N --> O["Verify deploy<br/>runtime signals, real journeys"]
  O --> P["Close the loop<br/>archive executor, close tasks"]
```

## 4. Dispatch records

`status.sh` refuses `accepted` (exit 4) until `ready.sh --key` has recorded a passing READY check for that dispatch. The verdict must cover the current PR head, the dispatch paths and its run, and must not come from `--allow-pending`. A change to the dispatch PR, paths or run clears the verdict.

```mermaid
stateDiagram-v2
  [*] --> running: status.sh dispatch KEY
  running --> awaiting_acceptance: executor reports done
  awaiting_acceptance --> accepted: READY recorded as ok
  awaiting_acceptance --> rejected: findings
  rejected --> running: fix round
  running --> abandoned
  awaiting_acceptance --> abandoned
  accepted --> [*]
  abandoned --> [*]
  note right of accepted
    Refused with exit 4
    unless ready.ok is true
  end note
```

## 5. The merge gate

The gate runs before every shell command. It finds `gh pr merge` and REST merge calls, runs `ready.sh` on the current head, and blocks the command when the fence is not met. It fails closed: a merge it cannot place is blocked.

```mermaid
sequenceDiagram
  participant A as Agent
  participant H as Harness (Claude Code or Codex)
  participant G as claude-merge-gate.sh
  participant R as ready.sh
  participant GH as GitHub REST
  A->>H: Bash: gh pr merge URL --squash
  H->>G: PreToolUse JSON (tool_input.command, cwd)
  G->>G: find merge targets in the command
  alt no merge in the command
    G-->>H: exit 0 (allow)
  else COORD_READY_OVERRIDE="reason"
    G->>G: append to .coordinator/overrides.log
    G-->>H: exit 0 (allow, report the override)
  else merge found
    G->>R: ready.sh URL (--allow-pending for --auto)
    R->>GH: PR, checks, required checks, reviews, files
    R->>R: pr-threads audit for owed replies
    alt READY (exit 0)
      R-->>G: READY
      G-->>H: exit 0 (allow)
    else NOT READY (1) or unreadable (3)
      R-->>G: BLOCK lines
      G-->>H: exit 2, reasons on stderr
      H-->>A: command refused with the reasons
    end
  end
```

What `ready.sh` blocks on, and what it only warns about:

```mermaid
flowchart LR
  subgraph BLOCK["BLOCK: NOT READY"]
    b1["closed or draft"]
    b2["head is not --sha"]
    b3["conflicts, behind,<br/>unknown mergeability"]
    b4["required check failing,<br/>missing or pending"]
    b5["latest review requests changes"]
    b6["owed replies or unsent drafts"]
    b7["files outside --paths"]
  end
  subgraph WARN["WARN: reported, not blocking"]
    w1["non-required check failing"]
    w2["tests deleted"]
    w3["CI, test or lint config changed"]
    w4["head not descended from base_sha"]
    w5["required-check list unreadable"]
  end
```

## 6. Keep-alive

Each session writes its state with `status.sh set`. The Stop hook reads it when the agent tries to end its turn. While the state is `active`, the hook sends the next action back as a new prompt.

```mermaid
stateDiagram-v2
  [*] --> active: status.sh set active "next action"
  active --> waiting: only CI, review or background runs remain
  active --> human_gate: the only blocker is a named person
  active --> done: fence met, with evidence
  waiting --> active: event arrives or recheck is due
  human_gate --> active: person answers
  done --> [*]
```

```mermaid
flowchart TD
  S["Agent tries to stop"] --> K{"COORD_KEEPALIVE=0<br/>or quiet hours?"}
  K -- "yes" --> P["Let the stop through"]
  K -- "no" --> F{"status.json state<br/>is active?"}
  F -- "no" --> P
  F -- "yes" --> O{"owner_session set and<br/>not this session?"}
  O -- "yes" --> P
  O -- "no" --> B{"busy_until<br/>in the future?"}
  B -- "yes" --> P
  B -- "no" --> C{"8 stops with no change to<br/>state, action, HEAD, worktree?"}
  C -- "yes, stalled" --> Q["Let the stop through;<br/>the sweeper takes over"]
  C -- "no" --> X["decision: block<br/>reason: Next action ... Do it now."]
```

The SessionStart hook covers the other end: a new, resumed or compacted session. While the state is `active`, `waiting` or `human-gate`, it adds the state, next action and open dispatches as context, and says to read the skill and the ledger first. After `resume` or `compact` it also says to run the sweep first. When another session owns the status, it says not to take over. It never blocks, and it prints nothing when the state is `done` or there is no status.

```mermaid
flowchart TD
  S0["Session starts, resumes,<br/>clears or compacts"] --> Z{"COORD_SESSION_START=0?"}
  Z -- "yes" --> N0["No output"]
  Z -- "no" --> F0{"status.json state is active,<br/>waiting or human-gate?"}
  F0 -- "no" --> A0{"COORD_SESSION_START=always<br/>and no status?"}
  A0 -- "yes" --> P0["One-line pointer to the skill"]
  A0 -- "no" --> N0
  F0 -- "yes" --> O0{"owner_session set and<br/>not this session,<br/>or session id empty?"}
  O0 -- "yes" --> X0["Context: state, next action;<br/>another session owns it,<br/>do not take over, message the owner"]
  O0 -- "no" --> R0{"source is resume<br/>or compact?"}
  R0 -- "yes" --> W0["Context: state, next action, dispatches;<br/>read skill and ledger; run the sweep first"]
  R0 -- "no" --> V0["Context: state, next action, dispatches;<br/>read skill and ledger"]
```

## 7. Review-thread audit

`pr-threads.sh` sorts every piece of review feedback into one of four categories: `ACTION`, `AWAITING`, `UNSENT` or `INFO`. It skips resolved threads. `INFO` marks a bot notice that needs no reply, such as a spent review quota (`COORD_NOTICE_PATTERNS`); it is listed but never blocks READY. A reply counts as the agent's only when it carries `AGENT_MARKER` (default `🤖` or the Claude Code footer).

```mermaid
flowchart TD
  I["Review thread, PR comment<br/>or review summary"] --> U{"Your own pending review<br/>with draft comments?"}
  U -- "yes" --> UN["UNSENT<br/>publish or delete it"]
  U -- "no" --> N{"PR comment or review summary<br/>that matches a bot-notice pattern?"}
  N -- "yes" --> IN["INFO<br/>notice, no reply needed,<br/>never blocks READY"]
  N -- "no" --> RS{"Thread resolved?"}
  RS -- "yes" --> SK["skipped"]
  RS -- "no" --> AR{"Agent-marked reply<br/>after the last comment?"}
  AR -- "no" --> AC["ACTION<br/>fix, evidence reply,<br/>or named human question"]
  AR -- "yes" --> AW["AWAITING<br/>unresolved, not done"]
```

## 8. Claude Code and Codex

Both harnesses send the same hook JSON, so one set of hooks serves both. The differences are in how sessions start and how a session knows its own id.

```mermaid
flowchart LR
  subgraph Shared["Same in both"]
    direction TB
    X1["SKILL.md rules"]
    X2["scripts/*.sh"]
    X3["hooks/*.sh<br/>PreToolUse matcher Bash,<br/>Stop decision: block,<br/>SessionStart additionalContext"]
  end
  subgraph Claude["Claude Code"]
    direction TB
    C1["install: ~/.claude/skills/"]
    C2["hooks: .claude/settings.json"]
    C3["start: claude -p<br/>cloud: create_session"]
    C4["resume: claude --resume ID -p"]
    C5["id: CLAUDE_CODE_SESSION_ID"]
    C6["repo rules: CLAUDE.md"]
  end
  subgraph Codex["Codex"]
    direction TB
    D1["install: ~/.agents/skills/"]
    D2["hooks: .codex/hooks.json<br/>trusted project"]
    D3["start: codex exec --sandbox workspace-write<br/>cloud: codex cloud exec --env"]
    D4["resume: codex exec resume ID"]
    D5["id: CODEX_THREAD_ID"]
    D6["repo rules: AGENTS.md"]
  end
  Claude --- Shared --- Codex
```

A child agent inherits its parent's environment. So a Codex executor started by a Claude coordinator sees both ids. `status.sh` picks the id that belongs to the nearest agent process:

```mermaid
flowchart TD
  A["status.sh set ..."] --> O{"COORD_SESSION_ID set?"}
  O -- "yes" --> U["use it"]
  O -- "no" --> W["walk up the parent processes"]
  W --> N{"first process named<br/>codex or claude"}
  N -- "codex, CODEX_THREAD_ID set" --> CX["owner = CODEX_THREAD_ID"]
  N -- "claude, CLAUDE_CODE_SESSION_ID set" --> CL["owner = CLAUDE_CODE_SESSION_ID"]
  N -- "none found, or its id is empty" --> FB["owner = CLAUDE_CODE_SESSION_ID,<br/>else CODEX_THREAD_ID"]
```
