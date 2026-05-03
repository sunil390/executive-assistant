---
name: noise-cancel
description: Filters inbox noise (Gmail, Google Chat) at three levels — pure, contextual, disguised signal. Learns from corrections. Use in morning_brief before any deep triage.
allowed-tools: Read, Write, Edit, Bash(jq:*), Skill(gchat), Agent
---

# Noise Cancel

Most email systems are binary (important / not). This skill is
ternary — the middle stage (`contextual`) is where the real value lives.

## The three levels

| Level | Criterion | Action |
|---|---|---|
| **Pure noise** | Newsletter unopened for 30d, automatic notification, pure FYI | Auto-archive, without reporting |
| **Contextual noise** | May matter later (course offer, event, paper) | Defer to weekly review (phase 1) |
| **Disguised signal** | Sender in `vip_senders` OR contains `vip_keywords` OR is reply to open thread | Promote to deep triage |

The skill **deletes nothing**. It moves to buckets. Operator validates edge cases.

## Flow

### Step 1 — Load learned filters

```bash
cat state/ea-state.json | jq '.noise_filters'
```

Patterns in `auto_archive_patterns` and `auto_defer_patterns` are treated as regex.
`vip_senders` and `vip_keywords` are overrides (always promote).

### Step 2 — Classify (in batch via subagent inbox-triager)

Delegate to subagent `inbox-triager` with mode=`noise_first_pass`. It receives the
list of messages (from gchat/gmail) and returns:

```json
{
  "pure_noise": [{ "id": "...", "matched_pattern": "..." }],
  "contextual": [{ "id": "...", "reason": "..." }],
  "disguised_signal": [{ "id": "...", "vip_match": "..." }],
  "uncertain": [{ "id": "...", "why": "..." }]
}
```

**Rule:** if any item matches `vip_*`, it goes to `disguised_signal` even if it
also matches an archive pattern. Override always wins.

### Step 3 — Apply actions

- `pure_noise` → archive via `gchat`/gmail skill, log id in `learning_log` with `action: archived`
- `contextual` → move to label "EA/Defer" (gmail) or flag deferred, log it
- `disguised_signal` → leave in inbox, flag for operator at next triage
- `uncertain` → ask the operator (max 5 per session; rest goes to `contextual`)

### Step 4 — Learn

Every time:
- Operator **rescues** an item from `pure_noise` → add exception (sender or keyword) to `vip_*`
- Operator **manually archives** an item that didn't match any pattern → propose new pattern at next weekly

Hook `PostToolUse` on inbox actions feeds `learning_log` automatically.

## State: noise_filters

```json
{
  "auto_archive_patterns": [
    "from:.*@noreply\\..*",
    "subject:.*\\[FYI\\].*",
    "list-id:.*newsletter.*"
  ],
  "auto_defer_patterns": [
    "subject:.*(course|webinar|training).*"
  ],
  "vip_senders": ["laiane@", "boss@google.com"],
  "vip_keywords": ["GymPulse", "mainframe-skills", "urgent"],
  "learning_log": [
    {
      "ts": "2026-05-01T08:30:00Z",
      "msg_id": "abc123",
      "auto_action": "archived",
      "operator_correction": "rescued",
      "proposed_exception": "sender:partner@x.com"
    }
  ]
}
```

## Calibration

Health criterion: **precision > 0.95 in pure_noise**. If operator rescued >5%
of what was auto-archived in the last 7 days, the skill **pauses auto-archive**
and requests tuning at next weekly review.

Hook `PostToolUse` calculates this rate. If >5%, writes
`state/ea-state.json :: stats.noise_cancel_health = "needs_tuning"` and the skill
refuses to run until phase 7 of the next review.

## Anti-patterns

- ❌ Delete (irreversible). Always archive.
- ❌ Learn silently. Every filter change goes through weekly review phase 7.
- ❌ Treat VIP as soft signal. VIP override always.
- ❌ "Important" without further qualification. Important for what? For which project?
