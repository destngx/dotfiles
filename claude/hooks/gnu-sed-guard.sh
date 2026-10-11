#!/bin/sh
# Block BSD-style `sed -i ''` in Bash tool calls. GNU sed (nix gnused) is first in PATH, where
# `-i ''` makes the empty string the script and the real script a filename.
#   PreToolUse (Bash): exit 2 rejects the call and feeds the reason back to the model.
# Explicit `/usr/bin/sed -i ''` (BSD) is left alone.

input="$(cat)"

case "$input" in
  *sed*) ;;
  *) exit 0 ;;
esac

command -v jq >/dev/null 2>&1 || exit 0
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"

if printf '%s' "$cmd" | grep -Eq "(^|[^/[:alnum:]_-])sed([[:space:]]+-[[:alnum:]-]+)*[[:space:]]+-i[[:space:]]+(''|\"\")"; then
  echo "Blocked: \`sed\` here is GNU sed, so \`sed -i ''\` treats '' as the script. Use \`sed -i 's/a/b/' file\` (no ''), or the Edit tool." >&2
  exit 2
fi

exit 0
