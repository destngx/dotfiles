#!/usr/bin/env bash

set -u

ACTION="${1:-notify}"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

USER_NAME="$(id -un)"
NIX_PROFILE="/etc/profiles/per-user/$USER_NAME/bin"
AEROSPACE="$NIX_PROFILE/aerospace"
HERDR="$NIX_PROFILE/herdr"
NOTIFIER="$(command -v terminal-notifier || true)"
if [ -z "$NOTIFIER" ] && [ -x /opt/homebrew/bin/terminal-notifier ]; then
  NOTIFIER="/opt/homebrew/bin/terminal-notifier"
fi
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

# terminal-notifier parses values starting with [ ( { " ' < as plist data; a leading backslash escapes them.
escape_arg() {
  case "$1" in
    [\[\(\{\"\'\<]*) printf '\\%s' "$1" ;;
    *) printf '%s' "$1" ;;
  esac
}

NOTIFY_ARGS=(
  -title "$(escape_arg "$TITLE")"
  -subtitle "$(escape_arg "$SUBTITLE")"
  -message "$(escape_arg "$MESSAGE")"
  -sound "$SOUND"
  -group "claude-$SESSION_ID"
  -execute "$SCRIPT_PATH focus $PANE_ID"
)

if [ -f "$CLAUDE_DIR/claude.png" ]; then
  NOTIFY_ARGS+=(-contentImage "$CLAUDE_DIR/claude.png")
fi

"$NOTIFIER" "${NOTIFY_ARGS[@]}"
