#!/usr/bin/env bash
# Keep the Mac awake (display may sleep) while any Claude Code session is working.
#   start: UserPromptSubmit  -> mark this session busy, start an Amphetamine session if none is active
#   stop:  Stop / SessionEnd -> unmark this session, end the Amphetamine session once no session is busy
# Only ends Amphetamine sessions this hook started, so manual sessions are left alone.
# Amphetamine keeps one session at a time and its AppleScript API exposes no session id,
# so the hook identifies its session by the IDs of the power assertions Amphetamine holds
# for it. Starting a manual session replaces those assertions, so the IDs stop matching and
# the hook leaves the manual session running.

set -u

ACTION="${1:-}"
STATE_DIR="${TMPDIR:-/tmp}/claude-amphetamine"
OWNED="$STATE_DIR/.owned"
LOCK="$STATE_DIR/.lock"

[ -d /Applications/Amphetamine.app ] || exit 0

SESSION_ID="$(jq -r '.session_id // ""' 2>/dev/null)"
[ -n "$SESSION_ID" ] || exit 0

mkdir -p "$STATE_DIR"

amph() { osascript -e "tell application \"Amphetamine\" to $1" 2>/dev/null; }

# IDs of the power assertions Amphetamine currently holds, one per line.
amph_assertions() {
  pmset -g assertions | grep -o '(Amphetamine): \[0x[0-9a-fA-F]*\]' | grep -o '0x[0-9a-fA-F]*' | sort
}

# PID of the claude process running this hook, used to prune markers of sessions that died without Stop.
claude_pid() {
  local pid=$PPID comm
  while [ "${pid:-1}" -gt 1 ]; do
    comm="$(ps -o comm= -p "$pid" 2>/dev/null)"
    [ "$(basename "$comm")" = "claude" ] && { echo "$pid"; return; }
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
}

acquire_lock() {
  local i
  for i in $(seq 50); do
    mkdir "$LOCK" 2>/dev/null && return 0
    sleep 0.1
  done
  rm -rf "$LOCK" && mkdir "$LOCK" 2>/dev/null
}
acquire_lock
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

prune_dead() {
  local f pid
  for f in "$STATE_DIR"/*; do
    [ -f "$f" ] || continue
    pid="$(cat "$f")"
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null || rm -f "$f"
  done
}

busy_count() { find "$STATE_DIR" -maxdepth 1 -type f ! -name '.*' | wc -l | tr -d ' '; }

case "$ACTION" in
  start)
    claude_pid > "$STATE_DIR/$SESSION_ID"
    if [ "$(amph 'session is active')" != "true" ]; then
      if amph 'start new session with options {duration:0, interval:0, displaySleepAllowed:true}' >/dev/null; then
        for _ in $(seq 20); do
          ids="$(amph_assertions)"
          [ -n "$ids" ] && break
          sleep 0.1
        done
        [ -n "$ids" ] && printf '%s\n' "$ids" > "$OWNED"
      fi
    fi
    ;;
  stop)
    rm -f "$STATE_DIR/$SESSION_ID"
    prune_dead
    if [ "$(busy_count)" -eq 0 ] && [ -f "$OWNED" ]; then
      [ "$(amph_assertions)" = "$(cat "$OWNED")" ] && amph 'end session' >/dev/null
      rm -f "$OWNED"
    fi
    ;;
esac

exit 0
