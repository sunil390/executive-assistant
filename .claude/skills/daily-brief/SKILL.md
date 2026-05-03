---
name: daily-brief
description: Morning ritual. Generates a 1-page brief with today's agenda, due commitments, already-filtered noise, and a top-3 priorities suggestion. Use in the morning or when the operator asks "what do I have today".
allowed-tools: Read, Write, Edit, Bash(jq:*), Bash(date:*), Skill(gcalendar), Skill(gchat), Skill(gdocs), Agent
---

# Daily Brief

Morning 1-page brief. Not a summary — a decision lever.

## Desired output

A document in `state/rituals/daily/<YYYY-MM-DD>.md` with **6 fixed sections**:

```markdown
# <YYYY-MM-DD>

## Agenda
- 10:00 1:1 with Laiane — meeting-prepper already ran? [link]
- 14:30 GymPulse Review — prep pending

## Commitments due today
- You → Pedro: send doc Y (declared yesterday)
- Beatriz → you: feedback on design Z (expiring)

## Open threads worth attention
- (up to 3, from people/*.yaml with recent last_contact + open_threads)

## Noise already handled
- 14 emails archived (newsletter, notifications)
- 2 deferred to weekly review

## Energy
- Free AM block: 09:00–11:30 (3 deep work blocks of 50min)
- PM dominated by meetings — don't schedule creative work

## Top 3 suggested
1. <priority>
2. <priority>
3. <priority>
```

## How to build it

Execution in **sequential phases**, each one a turn:

### Phase 1 — Agenda
- Call skill `gcalendar` (or a subagent using it): list today's and early tomorrow's events
- For each event: mark whether it already has a prep doc (`meeting-prepper` ran?)

### Phase 2 — Commitments
- Read `state/commitments/made-by-operator.json` filtered by `due.declared <= today`
- Read `state/commitments/made-to-operator.json` same filter
- For implicits: only those with `due.confidence >= medium`

### Phase 3 — Open threads
- Read `state/people/*.yaml`, filter by `open_threads.length > 0`
- Limit: 3 threads. More than that becomes noise.

### Phase 4 — Noise cancel
- **Delegate to subagent `inbox-triager`** with mode=`noise_first_pass`
- Operator doesn't see individual noise, only the counter

### Phase 5 — Energy
- Calculate free blocks between meetings (>50min)
- If PM has ≥3 meetings, flag as "PM saturated"

### Phase 6 — Top 3
- Combine: due commitments + projects with `next_action` and `last_touched > 7d`
- **Ask the operator**: "agree with these 3, or want to adjust?"
- Don't impose. Suggestion calibrates through acceptance over weeks.

## Quality rules

- **Brief must fit in 1 screen.** If it doesn't, you're including noise.
- **Each item has a clear action or gets cut.** "FYI" is not a brief.
- **Expiring commitments are visually highlighted** (e.g.: ⚠️). Don't bury them.
- **Don't include everything in the calendar** — only what needs prep or where operator is the owner.

## State update at the end

```json
{
  "rituals.last_morning_brief": "<ISO timestamp>",
  "today.date": "<YYYY-MM-DD>",
  "today.meetings": [<ids>],
  "today.commitments_due": [<ids>],
  "today.top_3_priorities": [<strings>],
  "mode.current": "active_day"
}
```

## Google Workspace integration

- **gcalendar**: list events, read description/attachments to detect prep needed
- **gdocs**: save brief in `Drive/EA/daily/<YYYY-MM-DD>.md` (mirror of state/)
- **gchat**: optional — post summary in a personal space

## Anti-patterns

- ❌ 3-page brief with every email of the day
- ❌ "Top 5" — forces real prioritization, keep it at 3
- ❌ List meetings without highlighting where prep is needed
- ❌ Repeat commitments without urgency flag
