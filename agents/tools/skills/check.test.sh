#!/usr/bin/env bash
# Tests for check.sh, new.sh and eval.sh --stage-only against fixture repos in both layouts, plus check.sh on this repo.
# Run: bash agents/tools/skills/check.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
mkdir -p "$REPO/tmp"
ROOT="$(mktemp -d "$REPO/tmp/skills-check-test.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT

passed=0
failed=0

fail() {
  echo "  FAIL: $*"
  failed=$((failed + 1))
  return 1
}

assert_eq() { [[ "$1" == "$2" ]] || fail "$3: expected '$2', got '$1'"; }
assert_contains() { [[ "$1" == *"$2"* ]] || fail "$3: expected output to contain '$2', got: $1"; }

# A fixture repo with one valid skill "land-it".
setup() {
  T="$ROOT/$1"
  mkdir -p "$T"
  git init -q "$T"
  local s="$T/.agents/skills/land-it"
  mkdir -p "$s/scripts" "$s/evals" "$T/.claude/skills"
  printf -- '---\nname: land-it\ndescription: Land a branch. Use when asked to land it.\n---\n\n# Land it\n' >"$s/SKILL.md"
  printf '#!/usr/bin/env bash\n' >"$s/scripts/land.sh"
  ln -s ../../.agents/skills/land-it "$T/.claude/skills/land-it"
  cat >"$s/telemetry.json" <<'EOF'
{"phrases": ["\\bland it\\b", "^\\s*ship\\s*$"], "script": "scripts/land.sh", "steps": ["prepare", "land"],
 "manual": ["\\bgit\\b[^|;&]*\\bpush\\b"]}
EOF
  cat >"$s/evals/triggers.json" <<'EOF'
{"fire": [{"name": "land-it", "prompt": "land it"}, {"name": "ship", "context": "Work is done.", "prompt": "ship"},
          {"name": "land-it-now", "prompt": "Please land it now"}],
 "no_fire": [{"name": "explain", "prompt": "how does landing work?"}, {"name": "open-pr", "prompt": "open a PR"},
             {"name": "land-plane", "prompt": "where do planes land?"}]}
EOF
}

check() {
  out="$(bash "$HERE/check.sh" --root "$T" 2>&1)"
  code=$?
}

test_valid_skill_passes() {
  setup valid
  check
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "1 skill(s) OK" "summary"
}

test_fire_prompt_must_match_a_phrase() {
  setup fire-miss
  jq '.fire += [{"name": "deploy-it", "prompt": "deploy it"}]' "$T/.agents/skills/land-it/evals/triggers.json" >"$T/t"
  mv "$T/t" "$T/.agents/skills/land-it/evals/triggers.json"
  check
  assert_eq "$code" 1 "exit code" || return
  assert_contains "$out" "fire prompt deploy-it matches no telemetry.json phrase" "message"
}

test_no_fire_prompt_must_not_match_a_phrase() {
  setup no-fire-hit
  jq '.no_fire += [{"name": "question", "prompt": "should I land it?"}]' \
    "$T/.agents/skills/land-it/evals/triggers.json" >"$T/t"
  mv "$T/t" "$T/.agents/skills/land-it/evals/triggers.json"
  check
  assert_contains "$out" "no_fire prompt question matches a telemetry.json phrase" "message"
}

test_bad_regex_is_reported() {
  setup bad-regex
  jq '.manual += ["(unclosed"]' "$T/.agents/skills/land-it/telemetry.json" >"$T/t"
  mv "$T/t" "$T/.agents/skills/land-it/telemetry.json"
  check
  assert_contains "$out" "manual regex does not compile: (unclosed" "message"
}

test_manual_pattern_with_dot_star_is_rejected() {
  setup dot-star
  jq '.manual += ["\\bgh\\b.*merge", "a\\.+b"]' "$T/.agents/skills/land-it/telemetry.json" >"$T/t"
  mv "$T/t" "$T/.agents/skills/land-it/telemetry.json"
  check
  assert_contains "$out" 'uses .* or .+, which the eval grader cannot keep inside the command: \bgh\b.*merge' "message" || return
  [[ "$out" != *'a\.+b'* ]] || fail "escaped dot was flagged"
}

test_missing_symlink_and_dangling_link_are_reported() {
  setup links
  rm "$T/.claude/skills/land-it"
  ln -s ../../.agents/skills/gone "$T/.claude/skills/gone"
  check
  assert_contains "$out" ".claude/skills/land-it must be a symlink" "missing link" || return
  assert_contains "$out" ".claude/skills/gone is a dangling symlink" "dangling link"
}

test_too_few_triggers_and_bad_names_are_reported() {
  setup few
  printf '{"fire": [{"name": "Bad Name", "prompt": "land it"}], "no_fire": []}\n' \
    >"$T/.agents/skills/land-it/evals/triggers.json"
  check
  assert_contains "$out" "at least 3 fire prompts, has 1" "fire count" || return
  assert_contains "$out" "at least 3 no_fire prompts, has 0" "no_fire count" || return
  assert_contains "$out" "bad case name Bad Name" "name"
}

test_skill_md_name_must_match_directory() {
  setup name
  printf -- '---\nname: other\ndescription: x\n---\n' >"$T/.agents/skills/land-it/SKILL.md"
  check
  assert_contains "$out" "frontmatter name must be land-it" "message"
}

test_new_scaffolds_a_skill_that_check_then_asks_to_fill() {
  setup new
  out="$(bash "$HERE/new.sh" --root "$T" tidy-up "Tidy the repo. Use when asked to tidy up." 2>&1)"
  assert_eq "$?" 0 "new exit code" || return
  [[ -f "$T/.agents/skills/tidy-up/SKILL.md" && -L "$T/.claude/skills/tidy-up" ]] || fail "skill or link missing" || return
  [[ -f "$T/.agents/skills/tidy-up/evals/triggers.json" && -f "$T/.agents/skills/tidy-up/telemetry.json" ]] ||
    fail "eval or telemetry file missing" || return
  check
  assert_eq "$code" 1 "check exit code" || return
  assert_contains "$out" "tidy-up: evals/triggers.json needs at least 3 fire prompts" "fill reminder"
}

test_new_never_overwrites() {
  setup new-existing
  echo '{"phrases": ["keep me"]}' >"$T/.agents/skills/land-it/telemetry.json"
  bash "$HERE/new.sh" --root "$T" land-it >/dev/null 2>&1
  assert_eq "$(jq -r '.phrases[0]' "$T/.agents/skills/land-it/telemetry.json")" "keep me" "telemetry.json"
}

test_new_needs_a_description_for_a_new_skill() {
  setup new-no-description
  bash "$HERE/new.sh" --root "$T" fresh >/dev/null 2>&1
  assert_eq "$?" 1 "exit code" || return
  [[ ! -e "$T/.agents/skills/fresh" ]] || fail "created a skill without a description"
}

test_stage_generates_trigger_cases_and_shared_graders() {
  setup stage
  local b="$T/.agents/skills/land-it/evals/behavior/happy"
  mkdir -p "$b/graders"
  printf -- '---\nallowed_tools: [Bash, Skill]\n---\n\nland it\n' >"$b/prompt.md"
  printf -- '---\ntype: llm\n---\nPASS if landed.\n' >"$b/graders/report.md"
  local stage
  stage="$(bash "$HERE/eval.sh" --root "$T" land-it --stage-only)" || fail "stage failed" || return
  local e="$stage/evals"
  assert_eq "$(find "$e/trigger" -name prompt.md | wc -l | tr -d ' ')" 6 "trigger cases" || return
  assert_contains "$(cat "$e/trigger/fire/ship/prompt.md")" $'Work is done.\n\nship' "context then prompt" || return
  assert_contains "$(cat "$e/trigger/no-fire/explain/graders/skill-no-fire.md")" "max: 0" "no-fire grader" || return
  [[ -f "$e/behavior/happy/graders/skill-fired.md" ]] || fail "skill-fired grader missing" || return
  assert_contains "$(cat "$e/behavior/happy/graders/no-manual.md")" '[^\"|;&]*\\bpush' "no-manual grader stays in the command" || return
  [[ -f "$e/_lib/sandbox.sh" ]] || fail "sandbox lib missing" || return
  [[ ! -e "$T/.agents/skills/land-it/evals/trigger" ]] || fail "generated files leaked into the skill"
}

# The dotfiles layout: agents/skills/<name> linked from claude/skills/<name>.
setup_dotfiles() {
  setup "$1"
  mv "$T/.agents" "$T/agents"
  rm -r "$T/.claude"
  mkdir -p "$T/claude/skills"
  ln -s ../../agents/skills/land-it "$T/claude/skills/land-it"
}

test_dotfiles_layout_passes() {
  setup_dotfiles dotfiles
  check
  assert_eq "$code" 0 "exit code: $out" || return
  assert_contains "$out" "1 skill(s) OK" "summary"
}

test_dotfiles_layout_wants_a_claude_link() {
  setup_dotfiles dotfiles-link
  rm "$T/claude/skills/land-it"
  check
  assert_contains "$out" "claude/skills/land-it must be a symlink to ../../agents/skills/land-it" "message"
}

test_new_in_dotfiles_layout() {
  setup_dotfiles dotfiles-new
  bash "$HERE/new.sh" --root "$T" tidy-up "Tidy the repo. Use when asked to tidy up." >/dev/null 2>&1
  assert_eq "$(readlink "$T/claude/skills/tidy-up")" "../../agents/skills/tidy-up" "link" || return
  [[ -f "$T/agents/skills/tidy-up/evals/triggers.json" && ! -e "$T/.agents" ]] || fail "wrong skill dir"
}

test_stage_in_dotfiles_layout() {
  setup_dotfiles dotfiles-stage
  local stage
  stage="$(bash "$HERE/eval.sh" --root "$T" land-it --stage-only)" || fail "stage failed" || return
  assert_eq "$(find "$stage/evals/trigger" -name prompt.md | wc -l | tr -d ' ')" 6 "trigger cases"
}

test_real_repo_passes() {
  out="$(bash "$HERE/check.sh" --root "$REPO" 2>&1)"
  assert_eq "$?" 0 "check on the real repo: $out"
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
