---
type: tool_used
tool: Bash
input_match: '"command"\s*:\s*"[^"]*\bgit\b[^"|;&]*\b(add|checkout|restore|commit|cherry-pick|mergetool)\b'
min: 0
max: 0
---

The skill says to report rebase conflicts and stop, never to resolve them silently.
