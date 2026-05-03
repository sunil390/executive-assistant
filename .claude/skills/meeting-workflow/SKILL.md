---
name: meeting-workflow
description: Coordinates the full meeting lifecycle (prep → execute → debrief). Blocks advance to prep if there is a pending debrief for a prior meeting with common participants. Use 30 min before a meeting or immediately after (hook detects).
allowed-tools: Read, Write, Edit, Bash(jq:*), Bash(date:*), Skill(gcalendar), Skill(gdocs), Agent
---

# Meeting Workflow

Meetings consume energy disproportionate to value delivered. This skill
transforms each meeting into a cycle:

```
prep (T-30min) → execute (operator) → debrief (T+5min) → action (state updated)
```

## Critical forcing function

**Does not run prep if there is a pending debrief from a prior meeting with common participants.**

Hook `check-pending-debriefs.sh` (PreToolUse) checks this. If there is one, this
skill refuses and forces the debrief first. You **never go into a meeting without
having processed the previous one**.

## PREP Phase (T-30min before)

Delegated to subagent `meeting-prepper`. It produces a briefing with 5 parts:

1. **Who is in the room** — for each participant:
   - Last contact (channel, date, topic) from `state/people/<id>.yaml`
   - Relevant open threads
   - Minimum personal context (role, shared projects)

2. **Why this meeting exists** — declared objective vs real objective
   - Declared: from calendar invite
   - Real: inferred from context (last 1:1, active shared projects)
   - If different, flag it

3. **What changed since the last** — updates in shared projects
   - For each `project_id` in common: decisions/blockers since last encounter

4. **3 questions worth asking** — generated from context, not generic
   - Based on `open_decisions` from shared projects
   - Based on pending commitments from/to participants

5. **Desired outcome** — what needs to be true at the end
   - Next action agreed? Decision made? Blocker unblocked?

Saved in `state/rituals/meetings/<event_id>-prep.md` and mirrored in gdocs (attached
to event via `gcalendar`).

## DEBRIEF Phase (T+5min after)

Delegated to subagent `meeting-debriefer`. It receives:

- Raw notes (from operator in gdocs or bullets dropped in chat)
- Transcript (if available via Meet)
- The prep doc generated earlier

It extracts (not summarizes — extracts):

### Decisions made (≠ topics discussed)

- Concrete decision + owner + reversibility

### Actions with owner and deadline

- Operator: goes to `commitment-tracker` in `made-by-operator.json`
- Others: goes to `commitment-tracker` in `made-to-operator.json`
- By project: routed via subagent `project-router`

### Implicit promises

This is the subtle part. Language such as:

- "I'll take a look"
- "I'll send it later"
- "Let me think about it"
- "We can talk about that"

**Does not become a commitment automatically.** The debriefer **asks**: "is this a
commitment? For when? For whom?" Response goes into `commitments/implicit.json`
with appropriate confidence.

### Relationship updates

- `state/people/<id>.yaml :: last_contact = { date, channel: meeting, topic }`
- Open threads: closed if discussion concluded, new if they arose

### Project updates

Via `project-router`: each extracted action is routed to a project_id (existing
or new) and `project-tracker` updates `next_action`/`blockers`/`recent_decisions`.

## Debrief output

```markdown
# Meeting <title> — <date>

## Decisions
- [DEC-001] X was decided by Y, reversible in 7d

## Actions
- [ACT-001] Operator → send Z to Pedro by 2026-05-05
- [ACT-002] Pedro → review W by 2026-05-07

## Detected implicits (awaiting confirmation)
- "I'll take a look at the proposal" — for whom? deadline?

## State updated
- people/pedro: last_contact, +1 open thread
- projects/gympulse: next_action changed, +1 decision
```

Saved in `state/rituals/meetings/<event_id>-debrief.md`.

## Why this skill is different from "auto meeting minutes"

Summary is overhead. **Updated state is leverage.** Every output of the skill
changes something concrete:
- New commitment registered and tracked
- Project with new next_action
- Person with updated thread
- Decision with date and reversibility

Meeting minutes that don't change state are ornamental work.

## Google Workspace integration

| Where | What |
|---|---|
| `gcalendar` | List event, read description/attendees, create follow-up events |
| `gdocs` | Read raw notes, save prep and debrief in Drive |
| `gchat` | Post prep doc in meeting space 30min before (optional) |

## Anti-patterns

- ❌ Skip debrief because "I remember everything" — memory decays, state persists
- ❌ Accept implicit as commitment automatically — noisy
- ❌ Generic prep ("prepare agenda") — must be specific to the context
- ❌ Debrief that becomes a textual transcript — extract actions, don't transcribe discussion
