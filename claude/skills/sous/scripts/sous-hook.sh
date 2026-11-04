#!/bin/sh
# Passes one Claude Code hook event to `sous hook <event>` (CONTRACTS.md section 5 in the monorepo's
# docs/sous). Sous starts each worker with SOUS_TASK_ID and SOUS_TASK_TOKEN, and the script passes
# every event for it. The two mates have SOUS_AGENT but no task id or token; they get only busy, stop
# and wake, so an inbox event reaches them by hook. Anything else, or no sous binary, prints nothing and
# exits 0, so the owner's own sessions are untouched.
#   busy:     UserPromptSubmit
#   idle:     StopFailure, SessionEnd
#   stop:     Stop, which may print {"decision": "block", ...} to keep the turn going
#   wake:     Stop, async with asyncRewake: blocks until the mate has an unread event, then prints one
#             stderr line and exits 2 to wake Claude; exits 0 on session end
#   pre-tool: PreToolUse on Edit, Write, MultiEdit and NotebookEdit, which may deny an edit to a fleet.toml
# Claude's hook JSON on stdin goes to sous unchanged.

{ [ -n "${SOUS_TASK_ID:-}" ] && [ -n "${SOUS_TASK_TOKEN:-}" ]; } ||
	{ [ -n "${SOUS_AGENT:-}" ] && case "${1:-}" in busy | stop | wake) true ;; *) false ;; esac; } ||
	exit 0

# `nx run sous:load-agent` installs the binary in ~/.local/bin, which a session started outside a
# login shell may not have on PATH.
sous="$(command -v sous 2>/dev/null)" || sous="$HOME/.local/bin/sous"
[ -x "$sous" ] || exit 0

exec "$sous" hook "$1"
