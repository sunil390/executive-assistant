#!/usr/bin/env bash
# PreToolUse hook — when mode is a locked-ritual mode, deny tool calls
# that aren't to the appropriate ritual skill/agent. This is the main
# forcing function that makes weekly_review uninterruptible.
set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib/common.sh"

payload="$(cat)"
tool_name="$(ea_payload_tool_name "$payload")"
sub="$(ea_payload_sub "$payload")"

if [ ! -f "$EA_STATE" ]; then ea_passthrough; exit 0; fi
mode="$(jq -r '.mode.current' "$EA_STATE")"

# Helper: is this a Skill/Agent call we care about?
is_orchestration_call=false
case "$tool_name" in
  Skill|Agent|Task|skill|agent|invoke_skill|invoke_subagent|run_skill) is_orchestration_call=true ;;
esac

case "$mode" in
  weekly_review)
    if [ "$is_orchestration_call" = "true" ]; then
      case "$sub" in
        weekly-review|"") ea_passthrough; exit 0 ;;
        *)
          ea_deny_tool "Mode weekly_review is locked. Only the 'weekly-review' skill may run. Attempt to invoke '$sub' was blocked. Complete the ritual first."
          exit 0
          ;;
      esac
    fi
    ;;
  quarterly_review)
    if [ "$is_orchestration_call" = "true" ]; then
      case "$sub" in
        quarterly-review|"") ea_passthrough; exit 0 ;;
        *)
          ea_deny_tool "Mode quarterly_review is locked. Only 'quarterly-review' is allowed."
          exit 0
          ;;
      esac
    fi
    ;;
  meeting_prep)
    if [ "$is_orchestration_call" = "true" ]; then
      case "$sub" in
        meeting-workflow|meeting-prepper|relationship-keeper|"") ea_passthrough; exit 0 ;;
        weekly-review|quarterly-review)
          ea_deny_tool "Meeting in <30 min. Do not start '$sub' now. Return after meeting_debrief."
          exit 0
          ;;
      esac
    fi
    ;;
esac

ea_passthrough
