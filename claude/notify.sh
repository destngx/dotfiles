#!/usr/bin/env bash

set -u

ACTION="${1:-notify}"

AEROSPACE="/opt/homebrew/bin/aerospace"
WEZTERM="/opt/homebrew/bin/wezterm"
NOTIFIER="/opt/homebrew/bin/terminal-notifier"

# ---------------------------------------------------------
# Notification click handler
# ---------------------------------------------------------
# IMPORTANT: Handle this before reading stdin.
if [ "$ACTION" = "focus" ]; then
  PANE_ID="${2:-}"

  # Hardcoded: WezTerm always lives on AeroSpace workspace 2.
  "$AEROSPACE" workspace 2

  # Focus the exact WezTerm pane running this Claude session.
  if [ -n "$PANE_ID" ]; then
    "$WEZTERM" cli activate-pane --pane-id "$PANE_ID"
  fi

  exit 0
fi

# ---------------------------------------------------------
# Claude Code hook
# ---------------------------------------------------------

INPUT="$(cat)"

EVENT="$(jq -r '.hook_event_name // ""' <<< "$INPUT")"
CWD="$(jq -r '.cwd // ""' <<< "$INPUT")"
SESSION_ID="$(jq -r '.session_id // "claude"' <<< "$INPUT")"

PROJECT="$(basename "$CWD")"
PANE_ID="${WEZTERM_PANE:-}"

[ ! -x "$NOTIFIER" ] && exit 0

case "$EVENT" in
  Notification)
    TYPE="$(jq -r '.notification_type // "notification"' <<< "$INPUT")"
    TITLE="$(jq -r '.title // "Claude Code"' <<< "$INPUT")"
    MESSAGE="$(jq -r '.message // "Claude Code needs your attention"' <<< "$INPUT")"

    case "$TYPE" in
      permission_prompt)
        SUBTITLE="Permission required · $PROJECT"
        SOUND="Ping"
        ;;
      idle_prompt)
        SUBTITLE="Waiting for you · $PROJECT"
        SOUND="Pop"
        ;;
      agent_needs_input)
        SUBTITLE="Agent needs input · $PROJECT"
        SOUND="Ping"
        ;;
      agent_completed)
        SUBTITLE="Agent completed · $PROJECT"
        SOUND="Glass"
        ;;
      *)
        SUBTITLE="$TYPE · $PROJECT"
        SOUND="default"
        ;;
    esac
    ;;

  Stop)
    TITLE="Claude Code"
    SUBTITLE="Completed · $PROJECT"
    SOUND="Glass"

    MESSAGE="$(
      jq -r '.last_assistant_message // "Task completed"' <<< "$INPUT" |
        tr '\n' ' ' |
        tr -s ' ' |
        cut -c1-350
    )"
    ;;

  *)
    exit 0
    ;;
esac

CLICK_COMMAND="$HOME/.claude/hooks/notify.sh focus $PANE_ID"

"$NOTIFIER" \
  -title "$TITLE" \
  -subtitle "$SUBTITLE" \
  -message "$MESSAGE" \
  -sound "$SOUND" \
  -contentImage "$HOME/.claude/claude.png" \
  -group "claude-$SESSION_ID" \
  -execute "$CLICK_COMMAND"
