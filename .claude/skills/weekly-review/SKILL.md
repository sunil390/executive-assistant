---
name: weekly-review
description: Weekly ritual with 7 phases (40 min). Forcing function that hooks make impossible to skip. Use Fri/Sat, or when hook ritual-check signals overdue. Locks other skills while running.
allowed-tools: Read, Write, Edit, Bash(jq:*), Bash(date:*), Skill(gdocs), Skill(gcalendar), Agent
---

# Weekly Review

Weekly ritual in 7 ordered phases. **Each phase has an exit criterion.** Does not
advance without closing. Hook `enter-review-mode.sh` locks other skills during
execution.

## Diagram

```
Phase 1: COLLECT      (5min)  aggregate what happened during the week
Phase 2: COMMITMENTS  (5min)  review of promises made/received
Phase 3: PROJECTS     (10min) status of each active project
Phase 4: ENERGY       (5min)  where energy went vs where it should have
Phase 5: NEXT WEEK    (10min) top 3 priorities for the coming week
Phase 6: DORMANT      (3min)  kill/resurrect/accept dormancy
Phase 7: NOISE TUNE   (2min)  refine noise filters
```

## Mode of operation

**Dialogue, not form.** You pull state, ask a directed question,
wait for answer, update state. Operator decides; you catalog.

For each phase:
1. Announce the phase (`## Phase N: <name>`)
2. Present the relevant state (max 1-2 screens)
3. Ask the **directed question** specific to the phase
4. Apply the decision (write to state)
5. Show exit criterion met before moving to next

## Phase 1 — COLLECT

**Directed question:** "Look at the week. What are you most proud of? What frustrated you most?"

**What to show:**
- Events from `gcalendar` for the week, grouped by day
- Commitments closed this week (status: completed)
- Projects with `last_touched` this week

**Exit criterion:** operator responded, note saved in `state/rituals/weekly/<YYYY-WW>.md`.

## Phase 2 — COMMITMENTS

**Directed question:** "Let's go through this list. For each one: done, still open, or dead?"

**What to show:**
- `made-by-operator.json` with status=open, grouped by counterparty
- `made-to-operator.json` with status=open, same
- `implicit.json` with confidence>=medium

**Apply:**
- Status updated per commitment
- Implicits become explicit (confirm deadline) or are demoted

**Exit criterion:** zero commitments with status `open` without a defined deadline.

## Phase 3 — PROJECTS

For each project in `state/projects/*.yaml` with status `active|shipping|iterating`:

**Directed question:** "<project>: status change? next_action still the same? anything blocking?"

**Apply:**
- `status` (keep / change)
- `next_action` (refine or replace)
- `blockers` (add/remove)
- `last_touched = now`

**Exit criterion:** all active+ projects visited, last_touched updated.

## Phase 4 — ENERGY

**Directed question:** "Looking at the week, did energy go where you wanted? What drained you?"

**What to show:**
- Comparison: time in meetings vs time in deep work (from gcalendar)
- Projects that received touches vs that received declarations ("I'll look at it")

**Apply:** adjust `operator.energy_pattern` if pattern changed.

**Exit criterion:** one sentence written by the operator in the review doc.

## Phase 5 — NEXT WEEK

**Directed question:** "Next week, if only 3 things happen, which ones must they be?"

**Apply:**
- `state/ea-state.json :: today.top_3_priorities` for next Monday
- Each one linked to a project_id or commitment_id

**Exit criterion:** exactly 3 priorities. Not 4, not 2.

## Phase 6 — DORMANT

**What to show:**
- Projects with `last_touched > dormancy.threshold_days`

**Directed question (per project):** "This one: kill (sunset), accept dormancy, or resurrect?"

**Apply:**
- `sunset` → `status: sunset`, move from `_index.json` to historical archive
- `dormant` → `status: dormant`, keep file, remove from active routing
- `resurrect` → `status: active`, define new `next_action`

**Exit criterion:** zero active projects with last_touched > 14d without a decision.

## Phase 7 — NOISE TUNE

**What to show:**
- `noise_filters.learning_log` for the week: auto-archived items that operator rescued
- Items operator manually archived that didn't match any pattern

**Directed question:** "These patterns: add, remove, or ignore?"

**Apply:**
- Update `auto_archive_patterns`, `auto_defer_patterns`, `vip_senders`
- Clear `learning_log`

**Exit criterion:** filters updated, log cleared.

## Final state update

```json
{
  "rituals.last_weekly_review": "<ISO>",
  "rituals.next_weekly_due": "<ISO + 7d>",
  "mode.current": "active_day"
}
```

And generate/save `state/rituals/weekly/<YYYY-WW>.md` with all decisions.

## Why dialogue, not form

Forms are filled on autopilot. Dialogue forces reflection. Each
directed question is built to prevent mechanical responses.

## Anti-patterns

- ❌ Skip a phase ("commitments are all OK, next")
- ❌ Top 5 instead of top 3
- ❌ Accept an active project without a next_action
- ❌ Skip phase 7 — that's where the system learns
- ❌ Allow the operator to enter the inbox in the middle of the review
