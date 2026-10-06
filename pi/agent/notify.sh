#!/usr/bin/env bash
set -u

HERDR="$(command -v herdr || true)"
NOTIFIER="$(command -v terminal-notifier || true)"
if [ -z "$NOTIFIER" ] && [ -x /opt/homebrew/bin/terminal-notifier ]; then
  NOTIFIER="/opt/homebrew/bin/terminal-notifier"
fi

ACTION="${1:-notify}"

if [ "$ACTION" = "focus" ]; then
  HERDR_PANE="${2:-}"
  [ -n "$HERDR_PANE" ] && [ -n "$HERDR" ] && "$HERDR" agent focus "$HERDR_PANE" >/dev/null 2>&1 || true
  exit 0
fi

TITLE="${1:-Pi}"
SUBTITLE="${2:-Completed}"
MESSAGE="${3:-Task completed}"
SOUND="${4:-Glass}"
SESSION_ID="${5:-pi}"
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
  NOTIFY_ARGS+=(-execute "$HOME/projects/dotfiles/pi/agent/notify.sh focus \"$HERDR_PANE\"")
fi

if [ -f "$HOME/.pi/agent/pi.png" ]; then
  NOTIFY_ARGS+=(-contentImage "$HOME/.pi/agent/pi.png")
elif [ -f "$HOME/.claude/claude.png" ]; then
  NOTIFY_ARGS+=(-contentImage "$HOME/.claude/claude.png")
fi

"$NOTIFIER" "${NOTIFY_ARGS[@]}" 2>/dev/null || true
