#!/usr/bin/env bash
# Stop hook — scan the assistant's last response for commitment-language
# emanating from the operator quoted earlier in the turn (e.g. the operator
# said "vou mandar pro Pedro amanhã"). When detected, inject a reminder so the
# orchestrator delegates to commitment-tracker.
#
# We deliberately do not auto-register; we only flag.
set -euo pipefail
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$HOOK_DIR/lib/common.sh"

payload="$(cat)"
text="$(ea_payload_last_text "$payload")"

# If we got nothing useful, bail silently
if [ -z "$text" ]; then ea_passthrough; exit 0; fi

# Phrase patterns suggesting an implicit operator promise
patterns=(
  "I'll send"
  "I'll check"
  "I'll send it to you"
  "I'll take a look"
  "let me think"
  "we can talk"
  "I'll talk to"
  "I'll send"
  "I'll look"
  "I'll get back"
  "let me check"
)

found=""
for p in "${patterns[@]}"; do
  if echo "$text" | grep -qiF "$p"; then
    found="$p"
    break
  fi
done

if [ -n "$found" ]; then
  ea_inject_context "[hook promise-detector] Possible implicit promise detected: \"$found\". Delegate to commitment-tracker (add_implicit) and ask the operator whether to confirm as a commitment with a deadline."
  exit 0
fi

ea_passthrough
