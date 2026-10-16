#!/bin/sh
# Show the `$bg` sidebar token only while a Claude pane is idle with background tasks still running.
# The count is written by claude/hooks/herdr-bg-tasks.sh; herdr's semantic state decides visibility.
#   apply.sh <pane_id>  called by the Claude hook after updating the count
#   apply.sh            called by herdr as a plugin event hook (pane from HERDR_PLUGIN_EVENT_JSON)
# The token is always derived from live state, so concurrent runs converge on the same value.

command -v jq >/dev/null 2>&1 || exit 0
herdr="${HERDR_BIN_PATH:-herdr}"
count_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-herdr-bg-idle"

pane="${1:-}"
[ -n "$pane" ] || pane="$(printf '%s' "${HERDR_PLUGIN_EVENT_JSON:-}" | jq -r 'first(.. | objects | .pane_id? | strings) // empty' 2>/dev/null)"
[ -n "$pane" ] || exit 0
count_file="$count_dir/$pane"

# Only panes the Claude hook has reported on; skips every other agent's state change.
[ -e "$count_file" ] || exit 0

if [ "${HERDR_PLUGIN_EVENT:-}" = "pane.closed" ]; then
  rm -f "$count_file"
  exit 0
fi

count="$(cat "$count_file" 2>/dev/null)"
status="$("$herdr" pane get "$pane" 2>/dev/null | jq -r '.result.pane | select(.agent == "claude") | .agent_status // empty')"

summary=""
if [ "$status" = "idle" ]; then
  case "$count" in
    "" | 0) ;;
    1) summary="1 bg task running" ;;
    *) summary="$count bg tasks running" ;;
  esac
fi

"$herdr" pane report-metadata "$pane" --source claude-bg-tasks --token bg="$summary" >/dev/null 2>&1 || true
exit 0
