---
name: quarterly-review
description: Quarterly ritual. Kills dormant projects, recalibrates north stars, audits accumulated noise filters. Forcing function that blocks a new quarter without completing the review.
allowed-tools: Read, Write, Edit, Bash(jq:*), Bash(date:*), Skill(gdocs), Agent
---

# Quarterly Review

Runs 4x per year. Hook blocks the start of a new quarter (1st business day of
Jan/Apr/Jul/Oct) without completing this ritual.

## Phases

### Phase 1 — North stars
For each project with status ≠ sunset: is `north_star` still true? Has what's at
stake changed? Operator re-writes or confirms each one.

### Phase 2 — Bulk sunset
Projects with status `dormant` for >60d: confirm sunset. Move files to
`state/projects/_archive/<YYYY-Q>/`.

### Phase 3 — Noise audit
Look at `noise_filters.learning_log` accumulated over the quarter. Which patterns
were useful (zero corrections)? Which were problematic (>10% corrections)?
Promote/deprecate.

### Phase 4 — Relationship cadences
For each `state/people/<id>.yaml` with `cadence.expected_days != null`: was the
cadence maintained? People silent for >2x cadence: revive contact or remove cadence.

### Phase 5 — Emerging patterns
Look at the 3 most recent weekly reviews. What patterns appear? (E.g.: "energy always
low on Wednesdays". "Project X has appeared in frustrations for 4 weeks".)
Operator decides what to do.

### Phase 6 — Next quarter
Top 3 **initiatives** (not projects) for the quarter. Coarser than weekly,
more granular than annual.

## Output

`state/rituals/quarterly/<YYYY-QN>.md` with decisions + state mutations
grouped. Attach to quarterly gdoc in Drive.

## Final state update

```json
{
  "rituals.last_quarterly_review": "<ISO>",
  "rituals.next_quarterly_due": "<ISO + 90d>"
}
```
