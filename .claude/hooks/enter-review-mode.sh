#!/usr/bin/env bash
# PreToolUse hook (matcher: weekly-review or quarterly-review) — flip the
# orchestrator into the review mode and lock other skills. filter-skills-by-mode
# enforces the lock; this hook just sets state.
set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib/common.sh"

payload="$(cat)"
sub="$(ea_payload_sub "$payload")"

case "$sub" in
  weekly-review)   target_mode="weekly_review" ;;
  quarterly-review) target_mode="quarterly_review" ;;
  *) ea_passthrough; exit 0 ;;
esac

if [ ! -f "$EA_STATE" ]; then ea_passthrough; exit 0; fi

now_iso="$(ea_now_iso)"
current="$(jq -r '.mode.current' "$EA_STATE")"
if [ "$current" != "$target_mode" ]; then
  ea_state_patch ".mode.previous = .mode.current
                | .mode.current = \"$target_mode\"
                | .mode.since = \"$now_iso\""
  ea_log "enter-review: $current -> $target_mode"
fi

ea_inject_context "Entering mode $target_mode. Other skills are locked until the ritual is complete. Do not respond to triages, drafts, or project status updates in this context."
