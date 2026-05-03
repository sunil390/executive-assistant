#!/usr/bin/env bash
# SessionStart hook — check for overdue rituals and force the appropriate mode.
# Runs after bootstrap.sh.
set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib/common.sh"

cat >/dev/null

if [ ! -f "$EA_STATE" ]; then
  ea_passthrough; exit 0
fi

today="$(ea_today)"
now_iso="$(ea_now_iso)"

# Weekly review due?
next_weekly="$(jq -r '.rituals.next_weekly_due // ""' "$EA_STATE")"
last_weekly="$(jq -r '.rituals.last_weekly_review // ""' "$EA_STATE")"
weekly_overdue="false"

if [ -n "$next_weekly" ]; then
  next_date="${next_weekly%%T*}"
  if [[ "$today" > "$next_date" ]] || [ "$today" = "$next_date" ]; then
    weekly_overdue="true"
  fi
elif [ -z "$last_weekly" ]; then
  # never ran one
  weekly_overdue="true"
fi

# Quarterly review?
next_q="$(jq -r '.rituals.next_quarterly_due // ""' "$EA_STATE")"
quarterly_overdue="false"
if [ -n "$next_q" ]; then
  q_date="${next_q%%T*}"
  if [[ "$today" > "$q_date" ]] || [ "$today" = "$q_date" ]; then
    quarterly_overdue="true"
  fi
fi

if [ "$quarterly_overdue" = "true" ]; then
  ea_state_patch ".mode.previous = .mode.current
                | .mode.current = \"quarterly_review\"
                | .mode.since = \"$now_iso\""
  ea_log "ritual-check: forcing quarterly_review"
  ea_inject_context "⚠️ Quarterly review is overdue. Mode switched to quarterly_review. Other skills are blocked until complete."
  exit 0
fi

if [ "$weekly_overdue" = "true" ]; then
  # Does not force automatically — asks. But marks mode as suggested.
  ea_inject_context "⚠️ Weekly review is overdue (last: ${last_weekly:-never}). Suggestion: run /weekly-review before anything else today."
  exit 0
fi

ea_passthrough
