# Executive Assistant — Architecture

> Digital chief-of-staff on Google Workspace. Central orchestrator, specialized
> subagents, workflow skills and hooks that turn executive discipline into
> infrastructure.

## 1. Philosophy

Three things that differentiate an EA from generic automation:

1. **Noise canceling** — filters noise **before** it reaches the operator.
2. **Continuity** — maintains context across days, projects, and people. The operator
   never re-explains what was already decided.
3. **Forcing functions** — enforces rituals (weekly review, sub-project routing,
   post-meeting debrief) that the operator would fail to maintain alone.

Division of responsibilities:

- **Skills** do the cognitive workflow work (rituals, briefs).
- **Subagents** do isolated, deep cognitive work (triaging, drafting).
- **Hooks** enforce operational discipline (state, gates, mode).
- **Orchestrator** decides what, when, and to whom.

## 2. Layer Typology

```
┌────────────────────────────────────────────────────────────────┐
│ ORQUESTRADOR EA — chief-of-staff loop                          │
│ Modo (manhã/dia/meeting/review/EOD) → seleciona skill/subagent │
└────────────────────────────────────────────────────────────────┘
        │
        ├── SKILLS (workflows com forcing function)
        │   ├─ ea-orchestrator       ─ entry point + modo
        │   ├─ daily-brief           ─ ritual matinal
        │   ├─ weekly-review         ─ ritual semanal (7 fases)
        │   ├─ noise-cancel          ─ triagem de ruído com aprendizado
        │   └─ meeting-workflow      ─ prep → execute → debrief
        │
        ├── SUBAGENTS (cognição isolada)
        │   ├─ inbox-triager         ─ classifica e prioriza Gmail
        │   ├─ meeting-prepper       ─ briefing pré-meeting
        │   ├─ meeting-debriefer     ─ extrai ações pós-meeting
        │   ├─ project-router        ─ roteia sinais a projetos
        │   ├─ project-tracker       ─ mantém estado de projetos
        │   ├─ commitment-tracker    ─ rastreia promessas
        │   ├─ relationship-keeper   ─ CRM pessoal
        │   └─ draft-composer        ─ escreve respostas/mensagens
        │
        ├── SKILLS PRÉ-EXISTENTES (Google Workspace)
        │   gdocs · gdrive · gcalendar · gchat · gsheets · gslides
        │
        └── HOOKS (disciplina operacional)
            SessionStart · UserPromptSubmit · PreToolUse · PostToolUse
            Stop · PreCompact · SessionEnd
```

### Skill vs. Subagent — when to use each

| Criterion | Skill | Subagent |
|---|---|---|
| Multi-phase loop with gates | ✅ | ❌ |
| Deep cognition in one turn | ❌ | ✅ |
| Forcing function (ritual) | ✅ | ❌ |
| Composition of multiple tools | ✅ | ✅ |
| Isolated context (doesn't pollute main) | ❌ | ✅ |
| Invoked by operator (`/weekly-review`) | ✅ | indirect |
| Invoked by another skill | ✅ | ✅ |

Practical rule: **skills choreograph, subagents execute**.

## 3. Persistent State

Everything written to `state/` at the repository root. Small files, JSON/YAML,
easy to audit and version.

```
state/
├── ea-state.json              # estado raiz: operator, mode, today, rituals
├── projects/
│   ├── <project-id>.yaml      # um por projeto ativo
│   └── _index.json            # mapa id → nome, status, last_touched
├── people/
│   └── <person-id>.yaml       # CRM pessoal
├── commitments/
│   ├── made-by-operator.json  # promessas do operador
│   ├── made-to-operator.json  # promessas pro operador
│   └── implicit.json          # zona cinza ("vou ver", "te mando")
└── rituals/
    ├── daily/<YYYY-MM-DD>.md  # daily briefs arquivados
    ├── weekly/<YYYY-WW>.md    # weekly reviews
    └── quarterly/<YYYY-QN>.md # quarterly reviews
```

**Hard rule:** every subagent that mutates state does so via JSON patch, never
re-writing the entire file. `PostToolUse` hooks apply the patch.

## 4. Orchestrator Modes

The orchestrator operates in modes. Each mode restricts which skills/subagents
are available. `UserPromptSubmit` and `PreToolUse` hooks enforce this.

| Mode | When | Available skills |
|---|---|---|
| `morning_brief` | 06:00–09:00 or first prompt of the day | daily-brief, noise-cancel |
| `active_day` | normal business day | inbox-triager, project-router, draft-composer, meeting-workflow |
| `meeting_prep` | T-30min before a gcalendar event | meeting-prepper, relationship-keeper |
| `meeting_debrief` | T+5min after an event | meeting-debriefer, commitment-tracker |
| `weekly_review` | Fri/Sat if overdue >7d | **only** weekly-review (locks others) |
| `quarterly_review` | quarterly | **only** quarterly-review |
| `end_of_day` | 18:00+ | eod-snapshot, commitment review |

## 5. Hooks — Claude Code Mapping

Gemini CLI semantics map to Claude Code like this:

| Gemini CLI       | Claude Code        | Role in EA |
|---|---|---|
| SessionStart     | SessionStart       | State bootstrap, ritual check |
| BeforeAgent      | UserPromptSubmit   | Injects mode context, forces overdue ritual |
| BeforeModel      | UserPromptSubmit   | (same event, distinct actions in the script) |
| BeforeToolSelection | PreToolUse      | Skill/subagent filter by mode |
| BeforeTool       | PreToolUse         | Skill precondition validation |
| AfterTool        | PostToolUse        | Updates state, scans commitments |
| AfterModel       | Stop               | Detects implicit promises, project mentions |
| PreCompress      | PreCompact         | Preserves CRM and ADRs |
| SessionEnd       | SessionEnd         | EOD snapshot |

## 6. Daily Loop (Example)

```
06:30  SessionStart
       └─ bootstrap.sh        loads ea-state.json
       └─ ritual-check.sh     "weekly review overdue 8d → mode=weekly_review"
                              OR "mode=morning_brief, daily-brief pending"

06:31  UserPromptSubmit ("good morning")
       └─ mode-context.sh     injects mode context + yesterday's top 3

06:32  /daily-brief           skill ea-orchestrator → daily-brief
       ├─ calls gcalendar     lists today's events
       ├─ calls subagent inbox-triager  classifies new emails
       ├─ calls noise-cancel  archives pure noise
       └─ produces 1-page brief in state/rituals/daily/2026-05-02.md

09:55  calendar webhook (T-30min meeting "1:1 Laiane")
       └─ hook schedules meeting_prep mode
       └─ subagent meeting-prepper runs automatically

10:30  meeting happens (operator takes raw notes in gdocs)

10:35  calendar webhook (event ended)
       └─ subagent meeting-debriefer → extracts actions
       └─ commitment-tracker registers "I'll send doc Y to Laiane Friday"
       └─ project-router routes actions to the right projects

18:30  SessionEnd
       └─ eod-snapshot.sh     summarizes day, closes state, schedules morning
```

## 7. Operational Principles

| Principle | Meaning |
|---|---|
| Delegate, don't duplicate | Orchestrator coordinates; subagents/skills analyze. |
| External state is source of truth | Model memory is volatile. Always re-read state. |
| Rituals are not optional | Hooks make skipping them impossible. |
| Nothing stays unrouted | Every signal goes into a project, person, or backlog. Orphan = failure. |
| Every skill produces a decision or state change | Summary is overhead. State change is leverage. |
| Continuous calibration | Router, noise filter, and ritual evolve through feedback. |
| Depth > speed | Use multiple turns. Shallow analysis is an orchestration failure. |
| Resumable by design | File-based state makes the system robust to interruptions. |

## 8. Anti-patterns

- **Skill that only summarizes.** Summary without state change is ornamental work.
- **Subagent that writes directly to root state.** Always via patch + hook.
- **Slow hook (>500ms).** Blocks the loop. Go async if heavy processing is needed.
- **Forcing function that can be skipped.** If "remind me" doesn't work, make it a blocker.
- **Auto-archive without an audit trail.** Archived noise must be auditable.
- **Silent router.** Every N routes, ask the operator for spot-check confirmation.

## 9. Scope of this repository's MVP

This repository implements:

- `state/` schemas + an initial seed state
- `.claude/skills/` 6 workflow skills (canonical)
- `.claude/agents/` 8 subagents (Claude Code)
- `.claude/hooks/` 12 discipline scripts (shared — payload-detect both runtimes)
- `.claude/settings.json` full Claude Code wiring
- `.gemini/skills/` mirrored from `.claude/skills/` via `scripts/sync-runtimes.sh`
- `.gemini/agents/` 8 native Gemini CLI subagents (frontmatter + structured handoffs)
- `.gemini/policies/ea-policies.toml` Policy Engine rules isolating what each subagent can write
- `.gemini/settings.json` Gemini CLI wiring (different events, same scripts)

What is **not** here (depends on the environment):

- Pre-existing Google Workspace skills (gdocs, gdrive, gcalendar, gchat,
  gsheets, gslides). The subagents/skills here assume they are available.
- Google Calendar webhook to trigger `meeting_prep`/`meeting_debrief`
  automatically — an external integration that invokes the orchestrator.

## 10. Dual runtime — Claude Code & Gemini CLI

The same stack (skills + subagents + hooks) runs on both runtimes. Differences
are isolated in three places: settings, hook event names, and how subagents
return work to the orchestrator.

### 10.1 Hook event mapping

| Gemini CLI event     | Claude Code event   | Script (canonical in `.claude/hooks/`) |
|----------------------|---------------------|--------------------------------------|
| SessionStart         | SessionStart        | bootstrap.sh, ritual-check.sh         |
| BeforeAgent          | UserPromptSubmit    | mode-context.sh                       |
| BeforeModel          | UserPromptSubmit    | (shared; rarely used)                 |
| BeforeToolSelection  | PreToolUse          | filter-skills-by-mode.sh              |
| BeforeTool           | PreToolUse          | check-pending-debriefs.sh, enter-review-mode.sh |
| AfterTool            | PostToolUse         | touch-projects.sh, scan-commitments.sh |
| AfterModel           | Stop                | promise-detector.sh, project-mention-tracker.sh |
| PreCompress          | PreCompact          | preserve-crm.sh                       |
| SessionEnd           | SessionEnd          | eod-snapshot.sh                       |
| Notification         | Notification        | (not used in MVP)                     |

`lib/common.sh` resolves `EA_ROOT` from `CLAUDE_PROJECT_DIR` or `GEMINI_PROJECT_DIR`
and exposes helpers (`ea_payload_tool_name`, `ea_payload_sub`, `ea_payload_last_text`)
that normalize payloads (Gemini's camelCase vs Claude Code's snake_case).

### 10.2 Critical difference: Gemini subagents cannot recurse

Official Gemini CLI docs:
> "Recursion protection: To prevent infinite loops and excessive token usage,
> subagents cannot call other subagents."

In Claude Code, subagents can call each other (via Skill/Agent tools). In Gemini
CLI they **cannot**. The orchestrator (main agent) is the one who coordinates handoffs.

**Mandatory pattern in Gemini subagents:** return a `handoffs[]` field in the
output that the orchestrator reads and dispatches. Example from `meeting-debriefer`:

```json
{
  "decisions": [...],
  "actions": [...],
  "handoffs": [
    { "to": "subagent:project-router",     "action": "route", "items": ["ACT-001"] },
    { "to": "subagent:commitment-tracker", "action": "add_batch", "commitments": [...] },
    { "to": "subagent:relationship-keeper","action": "apply_mutations", "items": [...] },
    { "to": "operator", "action": "confirm_implicits", "items": [...] }
  ]
}
```

The orchestrator executes handoffs in order. In Claude Code this pattern also
works, but the subagent can still **directly** invoke another if needed.

### 10.3 Tool mapping

Subagents declare tools in the frontmatter. Names differ:

| Capability        | Claude Code          | Gemini CLI                 |
|-------------------|----------------------|----------------------------|
| Read file         | `Read`               | `read_file`                |
| Write file        | `Write`              | `write_file`               |
| Edit file         | `Edit`               | `replace` / `edit_file`    |
| Search            | `Grep`               | `grep_search`              |
| Glob              | `Glob`               | `glob`                     |
| Shell             | `Bash(jq:*)`         | `run_shell_command` (granularity via Policy Engine) |
| Skill invocation  | `Skill`              | `@<skill-name>` or auto    |
| Agent invocation  | `Agent`/`Task`       | `@<agent-name>` or tool by name |
| MCP               | `mcp__server__tool`  | `mcp_server_*` wildcards   |

### 10.4 Source of truth vs copy

| Asset                    | Canonical source              | Mirror                        |
|--------------------------|-------------------------------|-------------------------------|
| Skills                   | `.claude/skills/`             | `.gemini/skills/` (via sync)  |
| Subagents — Claude       | `.claude/agents/`             | (not mirrored)                |
| Subagents — Gemini       | `.gemini/agents/`             | (not mirrored)                |
| Hooks                    | `.claude/hooks/`              | (not mirrored; Gemini references same path) |
| State                    | `state/`                      | (shared between runtimes)     |
| Policy (Gemini)          | `.gemini/policies/ea-policies.toml` | (Claude uses `permissions` in settings.json) |

`scripts/sync-runtimes.sh` keeps only skills in sync (format is compatible).
Subagents are a separate source because the orchestration models differ.

### 10.5 When to update what

| Change                                    | Edit                                           | Sync? |
|-------------------------------------------|------------------------------------------------|-------|
| Skill logic (workflow)                    | `.claude/skills/<name>/SKILL.md`               | ✅ run `scripts/sync-runtimes.sh` |
| Claude-only subagent                      | `.claude/agents/<name>.md`                     | —     |
| Gemini-only subagent                      | `.gemini/agents/<name>.md`                     | —     |
| Hook script                               | `.claude/hooks/<file>.sh`                      | — (referenced by both configs) |
| Claude permission                         | `.claude/settings.json :: permissions.allow`   | —     |
| Gemini permission (per-subagent granular) | `.gemini/policies/ea-policies.toml`            | —     |
| Hook wiring in runtime                    | `.claude/settings.json` or `.gemini/settings.json` | —  |
