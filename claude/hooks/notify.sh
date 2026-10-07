#!/usr/bin/env bash

set -u

ACTION="${1:-notify}"

AEROSPACE="$(command -v aerospace || true)"
HERDR="$(command -v herdr || true)"
NOTIFIER="/opt/homebrew/bin/terminal-notifier"

# ---------------------------------------------------------
# Notification click handler
# ---------------------------------------------------------
# IMPORTANT: Handle this before reading stdin.
if [ "$ACTION" = "focus" ]; then
  PANE_ID="${2:-}"

  if [ -n "$PANE_ID" ] && [ -n "$HERDR" ]; then
    PANE_INFO="$("$HERDR" pane get "$PANE_ID" 2>/dev/null || true)"
    WORKSPACE_ID="$(printf '%s' "$PANE_INFO" | /usr/bin/plutil -extract result.pane.workspace_id raw -o - - 2>/dev/null || true)"
    TAB_ID="$(printf '%s' "$PANE_INFO" | /usr/bin/plutil -extract result.pane.tab_id raw -o - - 2>/dev/null || true)"

    [ -n "$AEROSPACE" ] && "$AEROSPACE" workspace 2 >/dev/null 2>&1 || true
    [ -n "$WORKSPACE_ID" ] && "$HERDR" workspace focus "$WORKSPACE_ID" >/dev/null 2>&1 || true
    [ -n "$TAB_ID" ] && "$HERDR" tab focus "$TAB_ID" >/dev/null 2>&1 || true
    "$HERDR" agent focus "$PANE_ID" >/dev/null 2>&1 || true
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
PANE_ID="${HERDR_PANE_ID:-}"

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
