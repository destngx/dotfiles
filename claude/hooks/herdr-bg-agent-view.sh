#!/bin/sh
# Follow a Claude subagent transcript (JSONL) as readable text in a herdr pane.
# Usage: herdr-bg-agent-view.sh <transcript.output>

tail -n +1 -F "$1" 2>/dev/null | jq --unbuffered -r '
  def clip(n): if length > n then .[0:n] + "…" else . end;
  def text: if type == "string" then . else (map(.text? // empty) | join("\n")) end;
  (.message.content // empty) as $c
  | if .type == "assistant" and ($c | type) == "array" then
      $c[]
      | if .type == "text" then "\u001b[1;34m● \u001b[0m" + .text
        elif .type == "tool_use" then
          "\u001b[1;33m⏺ " + .name + "\u001b[0m "
          + ((.input.description // .input.command // .input.prompt // .input.message // .input.file_path // "") | tostring | clip(200))
        else empty end
    elif .type == "user" and ($c | type) == "array" then
      $c[] | select(.type == "tool_result")
      | "\u001b[2m" + (.content | text | clip(2000)) + "\u001b[0m"
    elif .type == "user" and ($c | type) == "string" and ($c | startswith("<system-reminder>") | not) then
      "\u001b[1;35m▶ prompt\u001b[0m " + ($c | clip(500))
    else empty end
'
