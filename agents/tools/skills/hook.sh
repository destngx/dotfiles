#!/usr/bin/env bash
# Claude Code hook that records how the project's skills (.agents/skills/<name>, see lib.sh) are used, one JSON line
# per event in <git common dir>/skill-telemetry/events.jsonl, so every worktree writes to the same log. Read it with
# report.sh.
#
#   prompt   UserPromptSubmit: a prompt matching one of the skill's trigger phrases, with a 160-character snippet.
#            Other prompts are not logged.
#   skill    PreToolUse on Skill: the model invoked a skill (repo=false for skills from outside this repo).
#   step     PostToolUse / PostToolUseFailure on Bash running a skill's script: subcommand, exit code, key=value output.
#   manual   PreToolUse on Bash while a skill is active in the session (called in the last 3 hours): a command
#            matching the skill's "manual" patterns, which its script is meant to run instead.
#
# Every skill with a SKILL.md gets skill events. An optional telemetry.json next to the SKILL.md adds the rest: phrases
# and manual are case-insensitive regexes (Oniguruma, as jq's test()), script is the skill script's path relative to
# the skill, steps lists its subcommands. See README.md next to this script.
#
# Env: SKILL_TELEMETRY_DIR overrides the log directory. The hook never blocks or fails the session: errors go to
# hook-errors.log in the log directory and the hook still exits 0.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ACTIVE_SECONDS=$((3 * 3600))

input="$(cat)"

log_dir() {
  if [[ -n "${SKILL_TELEMETRY_DIR:-}" ]]; then
    echo "$SKILL_TELEMETRY_DIR"
    return
  fi
  local common
  common="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir)" || return 1
  echo "$common/skill-telemetry"
}

# Prints the skills catalog: one JSON object per skill (a directory with a SKILL.md), {name} plus its telemetry.json.
catalog() {
  local d name
  skills_layout "$1"
  for d in "$1/$SKILLS_DIR"/*/; do
    [[ -f "$d/SKILL.md" ]] || continue
    name="$(basename "$d")"
    if [[ -f "$d/telemetry.json" ]]; then
      jq -c --arg name "$name" '{name: $name} + .' "$d/telemetry.json" || return 1
    else
      jq -nc --arg name "$name" '{name: $name}'
    fi
  done
}

emit() {
  jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg session "$session" '{ts: $ts, session: $session} + .' \
    >>"$dir/events.jsonl"
}

on_prompt() {
  local prompt
  prompt="$(jq -r '.prompt // ""' <<<"$input")"
  # Background-task notifications arrive as prompts. They are not the user's words.
  [[ "$prompt" != "<task-notification>"* ]] || return 0
  jq -c --arg p "$prompt" '
    first(.phrases[]? as $re | select($p | test($re; "i")) | $re) as $phrase
    | {event: "prompt", skill: .name, phrase: $phrase, text: ($p | .[:160])}' <<<"$skills"
}

on_skill() {
  jq -c --argjson names "$(jq -s 'map(.name)' <<<"$skills")" '
    (.tool_input.skill // "" | sub("^[\\w-]+:"; "")) as $name
    | select($name != "")
    | {event: "skill", skill: $name, repo: ($names | index($name) != null)}
      + (if .tool_input.args then {args: (.tool_input.args | tostring | .[:160])} else {} end)' <<<"$input"
}

on_step() {
  local command
  command="$(jq -r '.tool_input.command // ""' <<<"$input")"
  jq -c --arg cmd "$command" --argjson in "$input" '
    select(.script) | .name as $name | (.script | sub("^scripts/"; "")) as $file
    | ([$cmd | capture("skills/" + $name + "/scripts/" + $file + "(?:\\s+(?<step>[\\w-]+))?")] | first) as $m
    | select($m)
    | (if $in.hook_event_name == "PostToolUseFailure" then
         {exit: ([$in.error // "" | capture("Exit code (?<n>\\d+)").n | tonumber] | first),
          text: ($in.error // "")}
       else
         {exit: ($in.tool_response.exitCode // $in.tool_response.exit_code // 0),
          text: ($in.tool_response.stdout // "")}
       end) as $r
    | {event: "step", skill: .name, step: ($m.step // ""), exit: $r.exit,
       out: ([$r.text | splits("\n") | capture("^(?<k>[a-z_][\\w.]*)=(?<v>.*)$")? | {(.k): (.v | .[:200])}] | add // {})}
    ' <<<"$skills"
}

# Skills the model invoked in this session within the active window.
active_skills() {
  [[ -f "$dir/events.jsonl" ]] || return 0
  tail -n 5000 "$dir/events.jsonl" | jq -r --arg s "$session" --argjson window "$ACTIVE_SECONDS" '
    select(.session == $s and .event == "skill")
    | select((now - (.ts | fromdateiso8601)) < $window) | .skill' | sort -u
}

on_bash_pre() {
  local command active
  command="$(jq -r '.tool_input.command // ""' <<<"$input")"
  active="$(active_skills | jq -R . | jq -sc .)" || return 1
  [[ "$active" != "[]" ]] || return 0
  jq -c --arg cmd "$command" --argjson active "$active" '
    select(.name as $n | $active | index($n))
    | .name as $name | select($cmd | contains("skills/" + $name + "/scripts/") | not)
    | first(.manual[]? as $re | select($cmd | test($re; "i")) | $re) as $re
    | {event: "manual", skill: .name, pattern: $re, command: ($cmd | .[:300])}' <<<"$skills"
}

main() {
  local event tool root
  jq -e 'type == "object"' >/dev/null <<<"$input" || { echo "payload is not a JSON object: ${input:0:200}"; return 1; }
  event="$(jq -r '.hook_event_name // ""' <<<"$input")"
  tool="$(jq -r '.tool_name // ""' <<<"$input")"
  session="$(jq -r '.session_id // ""' <<<"$input")"
  root="${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "."' <<<"$input")}"
  skills="$(catalog "$root")" || return 1
  [[ -n "$skills" ]] || return 0

  local out
  case "$event:$tool" in
    UserPromptSubmit:*) out="$(on_prompt)" ;;
    PreToolUse:Skill) out="$(on_skill)" ;;
    PreToolUse:Bash) out="$(on_bash_pre)" ;;
    PostToolUse:Bash | PostToolUseFailure:Bash) out="$(on_step)" ;;
    *) return 0 ;;
  esac || return 1
  [[ -n "$out" ]] || return 0
  emit <<<"$out"
}

dir="$(log_dir "${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "."' <<<"$input" 2>/dev/null || echo .)}" 2>/dev/null)" || dir=""
if [[ -z "$dir" ]] || ! mkdir -p "$dir" 2>/dev/null; then
  echo "skill-telemetry: no log directory, event dropped" >&2
  exit 0
fi
session=""
skills=""
if ! err="$(main 2>&1 >/dev/null)"; then
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${err:-unknown error}" >>"$dir/hook-errors.log"
fi
exit 0
