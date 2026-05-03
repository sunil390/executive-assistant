#!/usr/bin/env bash
# UserPromptSubmit hook — inject mode-specific context every prompt
# so the orchestrator never drifts about which mode it's in.
set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib/common.sh"

# Consume payload (we don't need fields here, but must not break stdin)
cat >/dev/null

if [ ! -f "$EA_STATE" ]; then ea_passthrough; exit 0; fi

mode="$(jq -r '.mode.current' "$EA_STATE")"

case "$mode" in
  morning_brief)
    ctx="Mode: morning_brief. Recommended skill: daily-brief. Subagents: inbox-triager, project-tracker."
    ;;
  active_day)
    ctx="Mode: active_day. Operator drives. Subagents: inbox-triager, project-router, draft-composer, commitment-tracker."
    ;;
  meeting_prep)
    ctx="Mode: meeting_prep. Focus: meeting-prepper, relationship-keeper. Do not start other deep work."
    ;;
  meeting_debrief)
    ctx="Mode: meeting_debrief. Focus: meeting-debriefer, then commitment-tracker and project-router to route actions."
    ;;
  weekly_review)
    ctx="Mode: weekly_review. **LOCKED**. Only skill weekly-review. Do not respond to triages, drafts, or other tasks until the ritual is complete."
    ;;
  quarterly_review)
    ctx="Mode: quarterly_review. **LOCKED**. Only quarterly-review."
    ;;
  end_of_day)
    ctx="Mode: end_of_day. Focus: review due commitments, save snapshot, plan tomorrow. No new deep work."
    ;;
  *)
    ctx="Unknown mode: $mode. Falling back to active_day."
    ;;
esac

# Add hint about pending implicit commitments (always relevant)
implicit_count="$(jq '.commitments | length' "${EA_ROOT}/state/commitments/implicit.json" 2>/dev/null || echo 0)"
if [ "${implicit_count:-0}" -gt 0 ]; then
  ctx="${ctx}
${implicit_count} implicit commitment(s) awaiting confirmation."
fi

ea_inject_context "$ctx"
