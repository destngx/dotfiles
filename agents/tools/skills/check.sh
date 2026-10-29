#!/usr/bin/env bash
# Static checks for every skill in a repo (.agents/skills/<name>, or agents/skills/<name> in the dotfiles repo, see
# lib.sh). Free and fast (no Claude runs), so lint-staged runs it when a skill changes. Checks:
#   - SKILL.md has frontmatter with name equal to the directory name and a description
#   - .claude/skills/<name> is a symlink to ../../.agents/skills/<name>, and no .claude/skills link dangles
#   - telemetry.json, if present: known keys only, regexes compile, the script exists, steps are listed with a script
#   - evals/triggers.json exists with at least 3 fire and 3 no_fire prompts, unique kebab-case names, and (when
#     telemetry.json has phrases) every fire prompt matches a phrase and no no_fire prompt does, so the live
#     telemetry and the evals agree on what should trigger the skill
#   - every evals/behavior/<case>/ has a prompt.md, and its scaffold script exists
#
# Usage: bash ~/.agents/tools/skills/check.sh [--root <repo root>]   Exit 1 when any check fails.
# The root defaults to the git repo of the current directory.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
arg=""
[[ "${1:-}" == --root ]] && arg="$2"
root="$(skills_root "$arg")" || exit 1
skills_layout "$root"

problems=0
skills=0
problem() {
  echo "check: $1: $2" >&2
  problems=$((problems + 1))
}

# Prints a frontmatter value of a SKILL.md.
frontmatter() {
  awk -v key="$2" 'NR == 1 && $0 != "---" {exit} NR > 1 && $0 == "---" {exit}
    NR > 1 && index($0, key ":") == 1 {sub("^" key ":[ ]*", ""); print; exit}' "$1"
}

# Prints the regexes in a JSON array that jq cannot compile.
bad_regexes() {
  jq -r --arg key "$2" '.[$key] // [] | .[] | . as $re | try ("" | test($re; "i") | empty) catch $re' "$1"
}

check_telemetry() {
  local name="$1" t="$2/telemetry.json" bad script
  jq -e 'type == "object"' "$t" >/dev/null 2>&1 || { problem "$name" "telemetry.json is not a JSON object"; return; }
  bad="$(jq -r 'keys - ["phrases", "script", "steps", "manual"] | join(", ")' "$t")"
  [[ -z "$bad" ]] || problem "$name" "telemetry.json has unknown keys: $bad"
  for key in phrases manual; do
    jq -e --arg key "$key" '(.[$key] // []) | type == "array" and all(type == "string")' "$t" >/dev/null ||
      { problem "$name" "telemetry.json $key must be an array of strings"; continue; }
    while IFS= read -r bad; do
      [[ -z "$bad" ]] || problem "$name" "telemetry.json $key regex does not compile: $bad"
    done < <(bad_regexes "$t" "$key")
  done
  while IFS= read -r bad; do
    [[ -z "$bad" ]] || problem "$name" "telemetry.json manual pattern uses .* or .+, which the eval grader cannot keep inside the command: $bad"
  done < <(jq -r '.manual // [] | .[] | select(test("(^|[^\\\\])\\.[*+]"))' "$t")
  script="$(jq -r '.script // ""' "$t")"
  if [[ -n "$script" ]]; then
    [[ -f "$2/$script" ]] || problem "$name" "telemetry.json script $script does not exist"
    jq -e '.steps | type == "array" and length > 0' "$t" >/dev/null ||
      problem "$name" "telemetry.json lists a script but no steps (the last step marks a finished run)"
  fi
}

check_triggers() {
  local name="$1" dir="$2" f="$2/evals/triggers.json" n kind line
  [[ -f "$f" ]] || { problem "$name" "evals/triggers.json is missing (bash ~/.agents/tools/skills/new.sh $name scaffolds it)"; return; }
  jq -e 'type == "object"' "$f" >/dev/null 2>&1 || { problem "$name" "evals/triggers.json is not a JSON object"; return; }
  for kind in fire no_fire; do
    n="$(jq --arg k "$kind" '.[$k] // [] | length' "$f")"
    ((n >= 3)) || problem "$name" "evals/triggers.json needs at least 3 $kind prompts, has $n"
  done
  while IFS= read -r line; do
    [[ -z "$line" ]] || problem "$name" "evals/triggers.json: $line"
  done < <(jq -r '
    [(.fire // [])[], (.no_fire // [])[]] as $all
    | ($all[] | select((.name // "") | test("^[a-z0-9]+(-[a-z0-9]+)*$") | not) | "bad case name \(.name // "(none)")"),
      ($all[] | select((.prompt // "") == "") | "\(.name // "?") has no prompt"),
      ($all | group_by(.name)[] | select(length > 1) | "duplicate case name \(.[0].name)"),
      ($all[] | (keys - ["name", "context", "prompt"])[] | "unknown key \(.)")' "$f")

  local t="$dir/telemetry.json"
  [[ -f "$t" ]] && jq -e '(.phrases // []) | length > 0' "$t" >/dev/null 2>&1 || return 0
  [[ -z "$(bad_regexes "$t" phrases)" ]] || return 0
  while IFS= read -r line; do
    [[ -z "$line" ]] || problem "$name" "$line"
  done < <(jq -r --slurpfile t "$t" '
    def hit($p): any($t[0].phrases[]; . as $re | $p | test($re; "i"));
    (.fire // [])[] | select(hit(.prompt) | not)
      | "fire prompt \(.name) matches no telemetry.json phrase, so the report would not see it as a trigger: \(.prompt)"' "$f")
  while IFS= read -r line; do
    [[ -z "$line" ]] || problem "$name" "$line"
  done < <(jq -r --slurpfile t "$t" '
    def hit($p): any($t[0].phrases[]; . as $re | $p | test($re; "i"));
    (.no_fire // [])[] | select(hit(.prompt))
      | "no_fire prompt \(.name) matches a telemetry.json phrase, so the report would count it as a miss: \(.prompt)"' "$f")
}

check_behavior() {
  local name="$1" case_dir scaffold
  for case_dir in "$2"/evals/behavior/*/; do
    [[ -d "$case_dir" && "$(basename "$case_dir")" != _* ]] || continue
    [[ -f "$case_dir/prompt.md" ]] || problem "$name" "behavior case $(basename "$case_dir") has no prompt.md"
    if [[ -f "$case_dir/case.yaml" ]]; then
      scaffold="$(awk '/scaffold_script:/ {print $2}' "$case_dir/case.yaml")"
      [[ -z "$scaffold" || -f "$case_dir/$scaffold" ]] ||
        problem "$name" "behavior case $(basename "$case_dir") names scaffold $scaffold, which does not exist"
    fi
  done
}

for dir in "$root/$SKILLS_DIR"/*/; do
  dir="${dir%/}"
  name="$(basename "$dir")"
  skills=$((skills + 1))
  if [[ ! -f "$dir/SKILL.md" ]]; then
    problem "$name" "no SKILL.md"
    continue
  fi
  [[ "$(frontmatter "$dir/SKILL.md" name)" == "$name" ]] || problem "$name" "SKILL.md frontmatter name must be $name"
  [[ -n "$(frontmatter "$dir/SKILL.md" description)" ]] || problem "$name" "SKILL.md frontmatter has no description"
  link="$root/$SKILL_LINKS_DIR/$name"
  [[ -L "$link" && "$(readlink "$link")" == "../../$SKILLS_DIR/$name" ]] ||
    problem "$name" "$SKILL_LINKS_DIR/$name must be a symlink to ../../$SKILLS_DIR/$name"
  [[ ! -f "$dir/telemetry.json" ]] || check_telemetry "$name" "$dir"
  check_triggers "$name" "$dir"
  check_behavior "$name" "$dir"
done

for link in "$root/$SKILL_LINKS_DIR"/*; do
  [[ -L "$link" && ! -e "$link" ]] && problem "$(basename "$link")" "$SKILL_LINKS_DIR/$(basename "$link") is a dangling symlink"
done

if ((problems > 0)); then
  echo "check: $problems problem(s) in $skills skill(s)" >&2
  exit 1
fi
echo "check: $skills skill(s) OK"
