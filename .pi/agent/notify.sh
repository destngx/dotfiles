#!/usr/bin/env bash
set -u

AEROSPACE="/opt/homebrew/bin/aerospace"
WEZTERM="/opt/homebrew/bin/wezterm"
TMUX_BIN="/opt/homebrew/bin/tmux"
NOTIFIER="/opt/homebrew/bin/terminal-notifier"

ACTION="${1:-notify}"

# ---------------------------------------------------------
# 1. Click Handler: Focus AeroSpace -> WezTerm -> Tmux
# ---------------------------------------------------------
if [ "$ACTION" = "focus" ]; then
  WEZTERM_PANE="${2:-}"
  TMUX_PANE="${3:-}"

  # Step 1: Switch AeroSpace workspace to 2
  if [ -x "$AEROSPACE" ]; then
    "$AEROSPACE" workspace 2 2>/dev/null || true
  fi

  # Step 2: Focus the exact WezTerm pane
  if [ -n "$WEZTERM_PANE" ] && [ -x "$WEZTERM" ]; then
    "$WEZTERM" cli activate-pane --pane-id "$WEZTERM_PANE" 2>/dev/null || true
  fi

  # Step 3: Focus the exact Tmux window & pane inside WezTerm
  if [ -n "$TMUX_PANE" ] && [ -x "$TMUX_BIN" ]; then
    "$TMUX_BIN" select-window -t "$TMUX_PANE" 2>/dev/null || true
    "$TMUX_BIN" select-pane -t "$TMUX_PANE" 2>/dev/null || true
  fi

  exit 0
fi

# ---------------------------------------------------------
# 2. Notification Dispatcher
# ---------------------------------------------------------
TITLE="${1:-Pi}"
SUBTITLE="${2:-Completed}"
MESSAGE="${3:-Task completed}"
SOUND="${4:-Glass}"
SESSION_ID="${5:-pi}"
WEZTERM_PANE="${6:-${WEZTERM_PANE:-}}"
TMUX_PANE="${7:-${TMUX_PANE:-}}"

[ ! -x "$NOTIFIER" ] && exit 0

SCRIPT_PATH="$HOME/.pi/agent/notify.sh"
CLICK_COMMAND="$SCRIPT_PATH focus \"$WEZTERM_PANE\" \"$TMUX_PANE\""

NOTIFY_ARGS=(
  -title "$TITLE"
  -subtitle "$SUBTITLE"
  -message "$MESSAGE"
  -sound "$SOUND"
  -group "pi-$SESSION_ID"
)

if [ -n "$WEZTERM_PANE" ] || [ -n "$TMUX_PANE" ]; then
  NOTIFY_ARGS+=(-execute "$CLICK_COMMAND")
fi

if [ -f "$HOME/.pi/agent/pi.png" ]; then
  NOTIFY_ARGS+=(-contentImage "$HOME/.pi/agent/pi.png")
elif [ -f "$HOME/.claude/claude.png" ]; then
  NOTIFY_ARGS+=(-contentImage "$HOME/.claude/claude.png")
fi

"$NOTIFIER" "${NOTIFY_ARGS[@]}" 2>/dev/null || true

