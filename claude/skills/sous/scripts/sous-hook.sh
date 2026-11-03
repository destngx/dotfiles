#!/bin/sh
# Passes one Claude Code hook event to `sous hook <event>` (CONTRACTS.md section 5 in the monorepo's
# docs/sous). Sous starts each worker with SOUS_TASK_ID and SOUS_TASK_TOKEN. Without both, or without
# a sous binary, this script prints nothing and exits 0, so the owner's own sessions are untouched.
#   busy:     UserPromptSubmit
#   idle:     StopFailure, SessionEnd
#   stop:     Stop, which may print {"decision": "block", ...} to keep the turn going
#   pre-tool: PreToolUse on Edit, Write, MultiEdit and NotebookEdit, which may deny an edit to a fleet.toml
# Claude's hook JSON on stdin goes to sous unchanged.

[ -n "${SOUS_TASK_ID:-}" ] && [ -n "${SOUS_TASK_TOKEN:-}" ] || exit 0

# `nx run sous:load-agent` installs the binary in ~/.local/bin, which a session started outside a
# login shell may not have on PATH.
sous="$(command -v sous 2>/dev/null)" || sous="$HOME/.local/bin/sous"
[ -x "$sous" ] || exit 0

exec "$sous" hook "$1"
