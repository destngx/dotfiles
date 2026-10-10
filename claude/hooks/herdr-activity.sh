#!/bin/sh
# Report live counts of running tools and subagents to herdr as the `$run` sidebar token.
#   PreToolUse / PostToolUse(Failure): track tool calls (the Agent tool itself is counted as an agent).
#   SubagentStart / SubagentStop: track subagents (foreground and background).
#   Stop / UserPromptSubmit: drop main-thread tools whose Post hook never fired (e.g. interrupted).
#   SessionStart: reset state.
# Each running item is one file, so parallel hook invocations never clobber a shared counter.

input="$(cat)"

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

eval "$(printf '%s' "$input" | jq -r '
  @sh "event=\(.hook_event_name // "")",
  @sh "session=\(.session_id // "default")",
  @sh "tool=\(.tool_name // "")",
  @sh "tool_use_id=\(.tool_use_id // "")",
  @sh "agent_id=\(.agent_id // "")"
' 2>/dev/null)"

state_dir="${TMPDIR:-/tmp}/claude-herdr-activity/$session"
owner="${agent_id:-main}"
mkdir -p "$state_dir/tools" "$state_dir/agents"

case "$event" in
  SessionStart) rm -rf "$state_dir/tools"/* "$state_dir/agents"/* ;;
  PreToolUse)
    [ "$tool" != "Agent" ] && [ -n "$tool_use_id" ] && : >"$state_dir/tools/${owner}__$tool_use_id" ;;
  PostToolUse | PostToolUseFailure)
    [ -n "$tool_use_id" ] && rm -f "$state_dir/tools/${owner}__$tool_use_id" ;;
  SubagentStart)
    [ -n "$agent_id" ] && : >"$state_dir/agents/$agent_id" ;;
  SubagentStop)
    [ -n "$agent_id" ] && rm -f "$state_dir/agents/$agent_id" "$state_dir/tools/${agent_id}__"* ;;
  Stop | UserPromptSubmit)
    rm -f "$state_dir/tools/main__"* ;;
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

tools="$(find "$state_dir/tools" -type f | wc -l | tr -d ' ')"
agents="$(find "$state_dir/agents" -type f | wc -l | tr -d ' ')"

plural() { [ "$1" -eq 1 ] && printf '%s %s' "$1" "$2" || printf '%s %ss' "$1" "$2"; }
summary=""
[ "$tools" -gt 0 ] && summary="$(plural "$tools" tool)"
[ "$agents" -gt 0 ] && summary="${summary:+$summary · }$(plural "$agents" agent)"

herdr pane report-metadata "$HERDR_PANE_ID" --source claude-activity --token run="$summary" >/dev/null 2>&1 || true
exit 0
