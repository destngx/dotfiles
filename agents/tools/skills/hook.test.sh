#!/usr/bin/env bash
# Tests for hook.sh. Each case feeds a hook payload to the hook with a fixture skills catalog and a temporary log dir.
# Run: bash agents/tools/skills/hook.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/hook.sh"
REPO_TMP="$(git -C "$HERE" rev-parse --show-toplevel)/tmp"
mkdir -p "$REPO_TMP"
ROOT="$(mktemp -d "$REPO_TMP/skills-hook-test.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT

passed=0
failed=0

fail() {
  echo "  FAIL: $*"
  failed=$((failed + 1))
  return 1
}

assert_eq() { [[ "$1" == "$2" ]] || fail "$3: expected '$2', got '$1'"; }

# Fixture repo with one skill "land-it" whose script is scripts/land.sh.
setup() {
  T="$ROOT/$1"
  mkdir -p "$T/repo/.agents/skills/land-it" "$T/log"
  git init -q "$T/repo"
  printf -- '---\nname: land-it\ndescription: Land a branch.\n---\n' >"$T/repo/.agents/skills/land-it/SKILL.md"
  cat >"$T/repo/.agents/skills/land-it/telemetry.json" <<'EOF'
{
  "phrases": ["merge rebase", "proceed merge"],
  "script": "scripts/land.sh",
  "steps": ["prepare", "land"],
  "manual": ["\\bgit\\b[^|;&]*\\bpush\\b"]
}
EOF
}

# Feeds a payload (JSON, session s1 and cwd filled in) to the hook. Sets $code.
hook() {
  local payload
  payload="$(jq -c --arg cwd "$T/repo" '{session_id: "s1", cwd: $cwd} + .' <<<"$1")"
  CLAUDE_PROJECT_DIR="$T/repo" SKILL_TELEMETRY_DIR="$T/log" bash "$HOOK" <<<"$payload" >"$T/out" 2>&1
  code=$?
}

events() { [[ -f "$T/log/events.jsonl" ]] && jq -r "$1" "$T/log/events.jsonl"; }



test_trigger_phrase_records_a_snippet() {
  setup phrase
  hook '{"hook_event_name": "UserPromptSubmit", "prompt": "looks good, Merge Rebase it please"}'
  assert_eq "$(events '[.event, .skill, .phrase] | join(" ")')" "prompt land-it merge rebase" "event" || return
  assert_eq "$(events '.text')" "looks good, Merge Rebase it please" "snippet"
}

test_unrelated_prompt_is_not_logged() {
  setup unrelated
  hook '{"hook_event_name": "UserPromptSubmit", "prompt": "fix the login bug"}'
  assert_eq "$code" 0 "exit code" || return
  [[ ! -s "$T/log/events.jsonl" ]] || fail "unrelated prompt was logged: $(cat "$T/log/events.jsonl")"
}


# Background-task notifications reach the hook as prompts, and the command they echo often matches a phrase.
test_task_notification_is_not_logged() {
  setup notification
  hook '{"hook_event_name": "UserPromptSubmit", "prompt": "<task-notification>\n<summary>merge rebase run completed</summary>"}'
  assert_eq "$code" 0 "exit code" || return
  [[ ! -s "$T/log/events.jsonl" ]] || fail "notification was logged: $(cat "$T/log/events.jsonl")"
}

test_model_skill_call_is_recorded() {
  setup skill
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Skill", "tool_input": {"skill": "repo:land-it", "args": "feat/x"}}'
  assert_eq "$(events '[.event, .skill, .repo, .args] | map(tostring) | join(" ")')" "skill land-it true feat/x" "event"
}

test_skill_without_telemetry_json_is_still_recorded() {
  setup skill-no-telemetry
  mkdir -p "$T/repo/.agents/skills/plain"
  printf -- '---\nname: plain\ndescription: x\n---\n' >"$T/repo/.agents/skills/plain/SKILL.md"
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Skill", "tool_input": {"skill": "plain"}}'
  hook '{"hook_event_name": "UserPromptSubmit", "prompt": "plain please"}'
  assert_eq "$(events '[.event, .skill, .repo] | map(tostring) | join(" ")')" "skill plain true" "event"
}

test_directory_without_skill_md_is_not_a_skill() {
  setup no-skill-md
  rm "$T/repo/.agents/skills/land-it/SKILL.md"
  mkdir -p "$T/repo/.agents/skills/plain"
  printf -- '---\nname: plain\ndescription: x\n---\n' >"$T/repo/.agents/skills/plain/SKILL.md"
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Skill", "tool_input": {"skill": "land-it"}}'
  assert_eq "$(events '.repo')" "false" "repo flag"
}

test_skill_outside_the_repo_is_marked() {
  setup skill-global
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Skill", "tool_input": {"skill": "unslop"}}'
  assert_eq "$(events '[.skill, .repo] | map(tostring) | join(" ")')" "unslop false" "event"
}

test_script_step_success_records_exit_and_keys() {
  setup step-ok
  hook '{"hook_event_name": "PostToolUse", "tool_name": "Bash",
    "tool_input": {"command": "bash .agents/skills/land-it/scripts/land.sh prepare feat/x"},
    "tool_response": {"stdout": "branch=feat/x\nrewritten=no\nnoise line", "stderr": ""}}'
  assert_eq "$(events '[.event, .skill, .step, .exit] | map(tostring) | join(" ")')" "step land-it prepare 0" "event" || return
  assert_eq "$(events '.out | tostring')" '{"branch":"feat/x","rewritten":"no"}' "keys"
}

test_script_step_failure_records_exit_code() {
  setup step-fail
  hook '{"hook_event_name": "PostToolUseFailure", "tool_name": "Bash",
    "tool_input": {"command": "bash .agents/skills/land-it/scripts/land.sh prepare"},
    "error": "Exit code 3\nconflict=feature.txt\nland: rebase conflicted"}'
  assert_eq "$(events '[.step, .exit] | map(tostring) | join(" ")')" "prepare 3" "event" || return
  assert_eq "$(events '.out | tostring')" '{"conflict":"feature.txt"}' "keys"
}

test_other_bash_commands_are_ignored() {
  setup bash-other
  hook '{"hook_event_name": "PostToolUse", "tool_name": "Bash", "tool_input": {"command": "ls -la"},
    "tool_response": {"stdout": "a=b"}}'
  [[ ! -s "$T/log/events.jsonl" ]] || fail "plain command was logged"
}

test_manual_command_while_skill_active_is_a_deviation() {
  setup manual
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Skill", "tool_input": {"skill": "land-it"}}'
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "git -C ../wt push origin HEAD:main"}}'
  assert_eq "$(events 'select(.event == "manual") | [.skill, .command] | join(" ")')" \
    "land-it git -C ../wt push origin HEAD:main" "deviation"
}

test_manual_command_without_active_skill_is_ignored() {
  setup manual-idle
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "git push"}}'
  [[ ! -s "$T/log/events.jsonl" ]] || fail "push outside the skill was logged"
}

test_trigger_phrase_alone_does_not_activate_the_skill() {
  setup manual-phrase-only
  hook '{"hook_event_name": "UserPromptSubmit", "prompt": "merge rebase"}'
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "git push"}}'
  assert_eq "$(events 'select(.event == "manual") | .skill')" "" "deviation"
}

test_manual_command_in_another_session_is_ignored() {
  setup manual-other-session
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Skill", "tool_input": {"skill": "land-it"}}'
  hook '{"session_id": "s2", "hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": "git push"}}'
  assert_eq "$(events 'select(.event == "manual") | .skill')" "" "deviation"
}

test_the_skill_script_itself_is_not_a_deviation() {
  setup manual-script
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Skill", "tool_input": {"skill": "land-it"}}'
  hook '{"hook_event_name": "PreToolUse", "tool_name": "Bash",
    "tool_input": {"command": "bash .agents/skills/land-it/scripts/land.sh land # does git push"}}'
  assert_eq "$(events 'select(.event == "manual") | .skill')" "" "deviation"
}

test_bad_input_never_fails_the_session() {
  setup bad-input
  CLAUDE_PROJECT_DIR="$T/repo" SKILL_TELEMETRY_DIR="$T/log" bash "$HOOK" <<<"not json" >"$T/out" 2>&1
  assert_eq "$?" 0 "exit code" || return
  [[ -s "$T/log/hook-errors.log" ]] || fail "error was not written to hook-errors.log"
}

test_default_log_dir_is_shared_by_worktrees() {
  setup shared-dir
  git -C "$T/repo" -c user.email=t@e -c user.name=t commit -q --allow-empty -m init
  git -C "$T/repo" worktree add -q -b feat/y "$T/wt" 2>/dev/null
  mkdir -p "$T/wt/.agents/skills" && cp -r "$T/repo/.agents/skills/land-it" "$T/wt/.agents/skills/"
  jq -nc --arg cwd "$T/wt" '{session_id: "s1", cwd: $cwd, hook_event_name: "UserPromptSubmit", prompt: "merge rebase"}' |
    CLAUDE_PROJECT_DIR="$T/wt" bash "$HOOK"
  [[ -s "$T/repo/.git/skill-telemetry/events.jsonl" ]] || fail "log not in the common git dir"
}


for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  before=$failed
  "$t"
  if [[ $failed -eq $before ]]; then
    passed=$((passed + 1))
    echo "ok   $t"
  else
    echo "FAIL $t"
  fi
done

echo
echo "$passed passed, $failed failed"
[[ $failed -eq 0 ]]
