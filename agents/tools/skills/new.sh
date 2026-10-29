#!/usr/bin/env bash
# Scaffolds a skill, or the missing eval and telemetry files of an existing one, in the git repo of the current
# directory (or --root). Never overwrites a file. Paths below are for a project repo; the dotfiles repo uses
# agents/skills and claude/skills instead (see lib.sh).
#
# Usage: bash ~/.agents/tools/skills/new.sh [--root <repo root>] <name> ["<description>"]
#   .agents/skills/<name>/SKILL.md            only for a new skill; needs the description
#   .claude/skills/<name>                     symlink to ../../.agents/skills/<name>
#   .agents/skills/<name>/telemetry.json      empty phrases and manual; add script and steps if the skill has a script
#   .agents/skills/<name>/evals/triggers.json empty fire and no_fire lists
# Then fill in the lists until check.sh passes. See README.md next to this script.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

arg=""
if [[ "${1:-}" == --root ]]; then
  arg="$2"
  shift 2
fi
name="${1:-}"
description="${2:-}"
[[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { sed -n '6p' "$0" | sed 's/^# //' >&2; exit 1; }

repo="$(skills_root "$arg")"
skills_layout "$repo"
dir="$repo/$SKILLS_DIR/$name"

created() { echo "new: created ${1#"$repo"/}"; }

if [[ ! -f "$dir/SKILL.md" ]]; then
  [[ -n "$description" ]] || { echo "new: $name is a new skill, pass its description as the second argument" >&2; exit 1; }
  mkdir -p "$dir"
  printf -- '---\nname: %s\ndescription: %s\n---\n\n# %s\n' "$name" "$description" "$name" >"$dir/SKILL.md"
  created "$dir/SKILL.md"
fi

link="$repo/$SKILL_LINKS_DIR/$name"
if [[ ! -e "$link" && ! -L "$link" ]]; then
  mkdir -p "$repo/$SKILL_LINKS_DIR"
  ln -s "../../$SKILLS_DIR/$name" "$link"
  created "$link"
fi

if [[ ! -f "$dir/telemetry.json" ]]; then
  printf '{\n  "phrases": [],\n  "manual": []\n}\n' >"$dir/telemetry.json"
  created "$dir/telemetry.json"
fi

if [[ ! -f "$dir/evals/triggers.json" ]]; then
  mkdir -p "$dir/evals"
  printf '{\n  "fire": [],\n  "no_fire": []\n}\n' >"$dir/evals/triggers.json"
  created "$dir/evals/triggers.json"
fi

cat <<EOF

Next:
  1. evals/triggers.json: at least 3 fire and 3 no_fire entries, {"name": "kebab-case", "prompt": "...", "context": "optional"}.
     Use the words you really type; put close prompts that must not fire in no_fire.
  2. telemetry.json: phrases (regexes) that match every fire prompt and no no_fire prompt. For a skill with a script,
     add "script", "steps" (last one = done) and "manual" (commands only the script may run).
  3. Optional evals/behavior/<case>/ with prompt.md, graders/ and a scaffold.sh that sources ../../_lib/sandbox.sh.
  4. bash $HERE/check.sh, then bash $HERE/eval.sh $name.
EOF
