# Executive Assistant

Digital chief-of-staff on Google Workspace. Central orchestrator + specialized
subagents + workflow skills + hooks that turn executive discipline into
infrastructure.

**Runs on both runtimes:**

- **Claude Code** — config in `.claude/settings.json`, subagents in `.claude/agents/`
- **Gemini CLI** — config in `.gemini/settings.json`, native subagents in `.gemini/agents/`, policy isolation in `.gemini/policies/ea-policies.toml`

Skills, hooks, and state are shared.

> **Environment assumption:** Google Workspace skills (`gdocs`, `gdrive`,
> `gcalendar`, `gchat`, `gsheets`, `gslides`) are already available in the
> operator's runtime (as a native skill, MCP server, or extension). The
> subagents/skills here only compose them.

## Architecture — 30-second overview

```
ORQUESTRADOR (ea-orchestrator skill)
   ├─ SKILLS de workflow:    daily-brief, weekly-review, noise-cancel,
   │                         meeting-workflow, quarterly-review
   ├─ SUBAGENTS (8):         inbox-triager, meeting-prepper, meeting-debriefer,
   │                         project-router, project-tracker, commitment-tracker,
   │                         relationship-keeper, draft-composer
   ├─ SKILLS pré-existentes: gdocs · gdrive · gcalendar · gchat · gsheets · gslides
   └─ HOOKS (12 scripts):    SessionStart/UserPromptSubmit/PreToolUse/PostToolUse/
                             Stop/PreCompact/SessionEnd  (Claude Code)
                             SessionStart/BeforeAgent/BeforeToolSelection/BeforeTool/
                             AfterTool/AfterModel/PreCompress/SessionEnd  (Gemini CLI)
```

Full detail: [ARCHITECTURE.md](./ARCHITECTURE.md).

## Quickstart by runtime

### Running on Claude Code

1. Open a session in this directory.
2. Edit `state/ea-state.json` with your operator data.
3. Add projects in `state/projects/<id>.yaml` and update `state/projects/_index.json`.
4. Add key people in `state/people/<id>.yaml`.
5. Say "good morning" — the `bootstrap.sh` hook loads state and infers mode. For the weekly ritual, run `/weekly-review`.

### Running on Gemini CLI

1. Sync skills (idempotent):
   ```bash
   ./scripts/sync-runtimes.sh
   ```
2. Start `gemini` in this directory. `.gemini/settings.json` automatically loads:
   - **Hooks** (same scripts as Claude Code, referenced via `$GEMINI_PROJECT_DIR/.claude/hooks/...`)
   - **Subagents** in `.gemini/agents/` (8 hand-tuned with structured handoffs)
   - **Agent overrides** with `maxTurns`/`maxTimeMinutes` per subagent
3. For strong isolation, copy `.gemini/policies/ea-policies.toml` to `~/.gemini/policies/` (or point via Policy Engine setting). It restricts what each subagent can write.
4. Invoke a subagent explicitly: `@meeting-prepper prepare 1:1 with Laiane at 10am` or let automatic delegation decide.

### Orchestration difference

| | Claude Code | Gemini CLI |
|---|---|---|
| Subagent → subagent | ✅ allowed | ❌ forbidden (recursion guard) |
| Coordination | subagent or orchestrator | **always** orchestrator |
| Output pattern | free | **handoffs[]** structured mandatory |

Files in `.gemini/agents/` already reflect this pattern.

## Directory structure

```
.
├── ARCHITECTURE.md
├── README.md
├── .claude/
│   ├── settings.json              # wiring de hooks + permissões
│   ├── skills/
│   │   ├── ea-orchestrator/SKILL.md
│   │   ├── daily-brief/SKILL.md
│   │   ├── weekly-review/SKILL.md
│   │   ├── noise-cancel/SKILL.md
│   │   ├── meeting-workflow/SKILL.md
│   │   └── quarterly-review/SKILL.md
│   ├── agents/
│   │   ├── inbox-triager.md
│   │   ├── meeting-prepper.md
│   │   ├── meeting-debriefer.md
│   │   ├── project-router.md
│   │   ├── project-tracker.md
│   │   ├── commitment-tracker.md
│   │   ├── relationship-keeper.md
│   │   └── draft-composer.md
│   └── hooks/
│       ├── lib/common.sh
│       ├── bootstrap.sh             # SessionStart
│       ├── ritual-check.sh          # SessionStart
│       ├── mode-context.sh          # UserPromptSubmit
│       ├── filter-skills-by-mode.sh # PreToolUse
│       ├── check-pending-debriefs.sh# PreToolUse (meeting-prepper)
│       ├── enter-review-mode.sh     # PreToolUse (weekly/quarterly)
│       ├── touch-projects.sh        # PostToolUse
│       ├── scan-commitments.sh      # PostToolUse
│       ├── promise-detector.sh      # Stop
│       ├── project-mention-tracker.sh # Stop
│       ├── preserve-crm.sh          # PreCompact
│       └── eod-snapshot.sh          # SessionEnd
├── state/
│   ├── ea-state.json
│   ├── projects/
│   │   └── _index.json
│   ├── people/
│   ├── commitments/
│   │   ├── made-by-operator.json
│   │   ├── made-to-operator.json
│   │   └── implicit.json
│   └── rituals/
│       ├── daily/
│       ├── weekly/
│       ├── quarterly/
│       └── meetings/
└── templates/
    ├── ea-state.template.json
    ├── project.template.yaml
    ├── person.template.yaml
    └── commitment.template.json
```

## Quickstart

1. **Edit `state/ea-state.json`** with your operator data (name, role,
   current focus). The template ships with sensible defaults.

2. **Add active projects** by copying `templates/project.template.yaml` to
   `state/projects/<id>.yaml` and updating `state/projects/_index.json`.

3. **Add key people** (manager, direct reports, mentor, ~10 priority people)
   by copying `templates/person.template.yaml` to
   `state/people/<id>.yaml`.

4. **Check hooks**: `chmod +x .claude/hooks/*.sh` (already done on setup).

5. **Start a Claude Code session in this directory**. The
   `bootstrap.sh` hook loads your state and infers the mode. If it's morning,
   ask for `/daily-brief` or just say "good morning".

6. **Friday or Saturday**: run `/weekly-review`. Hooks lock other skills
   until the ritual completes.

## How the loop works

### Morning

```
06:30  SessionStart
   → bootstrap.sh        loads ea-state.json, detects hour < 11
                         and last_morning_brief != today → mode = morning_brief
   → ritual-check.sh     checks next_weekly_due

06:31  Operator: "good morning"
   → UserPromptSubmit/mode-context.sh injects:
     "Mode morning_brief. Recommended skill: daily-brief."

06:31  ea-orchestrator calls Skill:daily-brief
   → daily-brief uses gcalendar to list agenda
   → delegates to inbox-triager (subagent) for email classification
   → delegates to noise-cancel for auto-archive
   → produces 1-page brief in state/rituals/daily/2026-05-02.md
   → mode → active_day
```

### Before a meeting

```
09:55  Calendar webhook (T-30min meeting "1:1 Laiane")
   → ea-orchestrator detects proximity → mode = meeting_prep
   → invokes Skill:meeting-workflow phase=prep
   → hook check-pending-debriefs.sh:
     - checks if there's a prep without a debrief from previous meetings
     - if so: BLOCKS. operator completes debrief first.
   → meeting-prepper subagent generates prep doc (5 sections)
   → saves to state/rituals/meetings/<event>-prep.md + gdocs
```

### After a meeting

```
10:35  Operator pastes raw notes
   → ea-orchestrator → meeting-workflow phase=debrief
   → meeting-debriefer extracts DECISIONS, ACTIONS, IMPLICITS
   → commitment-tracker registers commitments (asking first for implicits)
   → project-router routes actions to projects
   → project-tracker updates next_action / blockers / decisions
   → relationship-keeper updates last_contact / threads
```

### Weekly review (Fri/Sat)

```
SessionStart Friday
   → ritual-check.sh detects next_weekly_due ≤ today
   → injects suggestion: "run /weekly-review before anything else"

Operator: /weekly-review
   → enter-review-mode.sh sets mode = weekly_review
   → filter-skills-by-mode.sh locks all other skills
   → weekly-review skill conducts 7 phases in dialogue
   → each phase updates state
   → at end: rituals.next_weekly_due = +7d, mode → active_day
```

### Context compaction (long sessions)

```
context fills → Claude Code triggers PreCompact
   → preserve-crm.sh saves snapshot of top-3, active projects, commitments
     in state/.snapshots/precompact-<ts>.md
   → injects: "After compaction, re-read this file and ea-state.json"
```

### End of day

```
SessionEnd
   → eod-snapshot.sh generates state/rituals/daily/<date>-eod.md
   → resets daily counters
   → mode → active_day
```

## Operational principles

| Principle | Meaning |
|---|---|
| Delegate, don't duplicate | Orchestrator coordinates; subagents/skills analyze. |
| External state is source of truth | Model memory is volatile. Re-read before acting. |
| Rituals are not optional | Hooks make skipping them impossible. |
| Nothing stays unrouted | Every signal goes into a project, person, or explicit backlog. |
| Every skill produces a decision or state change | Summary is overhead. State change is leverage. |
| Continuous calibration | Router, noise filter, and ritual evolve through feedback. |
| Depth > speed | Use multiple turns. Shallow analysis is an orchestration failure. |
| Resumable by design | File-based state makes the system robust to interruptions. |

## Customizing

- **Mode lock**: edit `filter-skills-by-mode.sh` to add new locked modes
  or soften existing locks.
- **Noise filters**: start by editing `state/ea-state.json :: noise_filters`.
  The `noise-cancel` skill learns and proposes adjustments in phase 7 of the weekly review.
- **People cadence**: declare in `state/people/<id>.yaml :: cadence` to
  receive alerts when the contact rhythm is violated.
- **Webhooks**: automatic triggering of `meeting_prep`/`meeting_debrief` based
  on the calendar is an external integration (Cloud Function that invokes the orchestrator).
  Without it, the operator calls `/meeting-prep <event_id>` manually.

## What is NOT here

- Implementation of Google Workspace skills — they are pre-existing in the environment.
- Cloud Function webhook to auto-trigger meeting phases.
- Dashboards/visualization — text-focused. Add a `visual-explainer` skill
  if you want HTML.
- Advanced self-healing for failing skills — a future extension over
  `PostToolUse` with `tool_response.error`.

## License

MIT — see [LICENSE](./LICENSE).
