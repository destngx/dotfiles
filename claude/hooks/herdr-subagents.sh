#!/bin/sh
# Report the live count of running subagents (foreground and background) to herdr as the `$agents`
# sidebar token.
#   SubagentStart / SubagentStop: track subagents.
#   SessionStart: reset state.
# Deliberately not hooked on tool events: those run synchronously on every tool call.
# Each running subagent is one file, so parallel hook invocations never clobber a shared counter.

input="$(cat)"

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

eval "$(printf '%s' "$input" | jq -r '
  @sh "event=\(.hook_event_name // "")",
  @sh "session=\(.session_id // "default")",
  @sh "agent_id=\(.agent_id // "")"
' 2>/dev/null)"

state_dir="${TMPDIR:-/tmp}/claude-herdr-subagents/$session"
mkdir -p "$state_dir/agents"

case "$event" in
  SessionStart) rm -f "$state_dir/agents"/* ;;
  SubagentStart) [ -n "$agent_id" ] && : >"$state_dir/agents/$agent_id" ;;
  SubagentStop) [ -n "$agent_id" ] && rm -f "$state_dir/agents/$agent_id" ;;
  *) exit 0 ;;
esac

# Serialize count+report so a stale count never overwrites a newer one.
lock="$state_dir/.lock"
i=0
until mkdir "$lock" 2>/dev/null; do
  i=$((i + 1))
  [ "$i" -ge 40 ] && rm -rf "$lock" && continue
  sleep 0.05
done
trap 'rmdir "$lock" 2>/dev/null' EXIT

agents="$(find "$state_dir/agents" -type f | wc -l | tr -d ' ')"
case "$agents" in
  0) summary="" ;;
  1) summary="1 agent" ;;
  *) summary="$agents agents" ;;
esac

herdr pane report-metadata "$HERDR_PANE_ID" --source claude-subagents --token agents="$summary" >/dev/null 2>&1 || true
exit 0
