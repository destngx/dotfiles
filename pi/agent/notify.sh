#!/usr/bin/env bash
set -u

AEROSPACE="$(command -v aerospace || true)"
NOTIFIER="$(command -v terminal-notifier || true)"
if [ -z "$NOTIFIER" ] && [ -x /opt/homebrew/bin/terminal-notifier ]; then
  NOTIFIER="/opt/homebrew/bin/terminal-notifier"
fi

ACTION="${1:-notify}"

if [ "$ACTION" = "focus" ]; then
  HERDR_PANE="${2:-}"
  if [ -n "$HERDR_PANE" ] && [ -n "$HERDR" ]; then
    PANE_INFO="$("$HERDR" pane get "$HERDR_PANE" 2>/dev/null || true)"
    WORKSPACE_ID="$(printf '%s' "$PANE_INFO" | /usr/bin/plutil -extract result.pane.workspace_id raw -o - - 2>/dev/null || true)"
    TAB_ID="$(printf '%s' "$PANE_INFO" | /usr/bin/plutil -extract result.pane.tab_id raw -o - - 2>/dev/null || true)"

    [ -n "$AEROSPACE" ] && "$AEROSPACE" workspace 2 >/dev/null 2>&1 || true
    [ -n "$WORKSPACE_ID" ] && "$HERDR" workspace focus "$WORKSPACE_ID" >/dev/null 2>&1 || true
    [ -n "$TAB_ID" ] && "$HERDR" tab focus "$TAB_ID" >/dev/null 2>&1 || true
    "$HERDR" agent focus "$HERDR_PANE" >/dev/null 2>&1 || true
  fi
  exit 0
fi

if [ "$ACTION" = "notify" ]; then
  shift
fi

TITLE="${1:-Pi}"
SUBTITLE="${2:-Completed}"
MESSAGE="${3:-Task completed}"
SOUND="${4:-Glass}"
SESSION_ID="${5:-pi}"
HERDR="$(command -v herdr || true)"
HERDR_PANE="${HERDR_PANE_ID:-}"

[ -n "$NOTIFIER" ] || exit 0

NOTIFY_ARGS=(
  -title "$TITLE"
  -subtitle "$SUBTITLE"
  -message "$MESSAGE"
  -sound "$SOUND"
  -group "pi-$SESSION_ID"
)

if [ -n "$HERDR_PANE" ]; then
  NOTIFY_ARGS+=(-execute "'$HOME/projects/dotfiles/pi/agent/notify.sh' focus '$HERDR_PANE'")
fi

if [ -f "$HOME/.pi/agent/pi.png" ]; then
  NOTIFY_ARGS+=(-contentImage "$HOME/.pi/agent/pi.png")
elif [ -f "$HOME/.claude/claude.png" ]; then
  NOTIFY_ARGS+=(-contentImage "$HOME/.claude/claude.png")
fi

"$NOTIFIER" "${NOTIFY_ARGS[@]}" 2>/dev/null || true
