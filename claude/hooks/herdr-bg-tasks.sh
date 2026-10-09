#!/bin/sh
# Surface Claude background tasks in herdr.
#   PostToolUse (async Agent): open a split pane following the subagent's transcript.
#   Stop / SubagentStop: report the `$bg` sidebar token from the `background_tasks`
#     snapshot and close panes whose task is no longer running.
# Set CLAUDE_HERDR_BG_DEBUG=1 to dump hook input to /tmp/claude-herdr-bg-<event>.json.

input="$(cat)"

[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
command -v herdr >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

field() { printf '%s' "$input" | jq -r "$1" 2>/dev/null; }

event="$(field '.hook_event_name // empty')"
session="$(field '.session_id // "default"')"
state_dir="${TMPDIR:-/tmp}/claude-herdr-bg/$session"

[ "${CLAUDE_HERDR_BG_DEBUG:-}" = "1" ] && printf '%s\n' "$input" >"/tmp/claude-herdr-bg-$event.json"

open_pane() {
  # Only background subagents get a pane; shell/MCP/monitor tasks show in the sidebar count only.
  [ "$(field '.tool_name')" = "Agent" ] || return 0
  [ "$(field '.tool_response.status // empty')" = "async_launched" ] || return 0
  task_id="$(field '.tool_response.agentId // empty')"
  [ -n "$task_id" ] || return 0
  viewer="$(dirname "$0")/herdr-bg-agent-view.sh"
  # Output lives at /tmp/claude-<uid>/<project-slug>/<session_id>/tasks/<task_id>.output
  tasks_dir="$(find "/tmp/claude-$(id -u)/" -maxdepth 3 -type d -path "*/$session/tasks" 2>/dev/null | head -1)"
  [ -n "$tasks_dir" ] || return 0
  out_file="$tasks_dir/$task_id.output"

  mkdir -p "$state_dir"
  # Stack task panes: first one splits Claude's pane right, later ones split the last task pane down.
  last_pane="$(cat "$state_dir"/*.pane 2>/dev/null | tail -1)"
  if [ -n "$last_pane" ]; then
    new_pane="$(herdr pane split "$last_pane" --direction down --no-focus 2>/dev/null | jq -r '.result.pane.pane_id // empty')"
  fi
  [ -n "${new_pane:-}" ] || new_pane="$(herdr pane split "$HERDR_PANE_ID" --direction right --ratio 0.6 --no-focus 2>/dev/null | jq -r '.result.pane.pane_id // empty')"
  [ -n "$new_pane" ] || return 0

  printf '%s\n' "$new_pane" >"$state_dir/$task_id.pane"
  desc="$(field '.tool_input.description // .tool_input.command' | cut -c1-60)"
  herdr pane rename "$new_pane" "bg $task_id: $desc" >/dev/null 2>&1 || true
  herdr pane run "$new_pane" "clear; $viewer '$out_file'" >/dev/null 2>&1 || true
}

report_and_reap() {
  # Absent field (older Claude Code): leave everything alone.
  [ "$(field 'has("background_tasks")')" = "true" ] || return 0

  running='[(.background_tasks // [])[] | select((.status // "running") | test("^(completed|failed|killed|stopped|done)$") | not)]'

  # e.g. "⚙ 3 bg · 2 shell 1 subagent"; empty clears the token
  summary="$(field "$running"' | if length == 0 then "" else "⚙ \(length) bg · " + (group_by(.type) | map("\(length) \(.[0].type // "task")") | join(" ")) end')"
  herdr pane report-metadata "$HERDR_PANE_ID" --source claude-bg-tasks --token bg="$summary" >/dev/null 2>&1 || true

  running_ids="$(field "$running"' | .[].id')"
  for f in "$state_dir"/*.pane; do
    [ -e "$f" ] || continue
    task_id="$(basename "$f" .pane)"
    printf '%s\n' "$running_ids" | grep -qx "$task_id" && continue
    herdr pane close "$(cat "$f")" >/dev/null 2>&1 || true
    rm -f "$f"
  done
}

case "$event" in
  PostToolUse) open_pane ;;
  Stop | SubagentStop) report_and_reap ;;
esac
exit 0
