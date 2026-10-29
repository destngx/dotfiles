#!/usr/bin/env bash
# Runs the eval suites of the skills in the git repo of the current directory (or --root) with `claude plugin eval`
# and appends the scores to <git common dir>/skill-telemetry/evals.jsonl, which report.sh shows next to the live
# telemetry.
#
# Usage: bash ~/.agents/tools/skills/eval.sh [--root <repo root>] <skill>|--all [--tag trigger|behavior|fire|no-fire]
#                                  [--case <glob>] [--runs <n>] [--stage-only] [-- <extra claude plugin eval args>]
#
# The suite is built in a staged copy of the skill under tmp/skill-evals/<skill>/<timestamp>/stage/<skill>:
#   - evals/triggers.json becomes one case per prompt in evals/trigger/fire/ and evals/trigger/no-fire/, each graded
#     on whether the model calls the skill (3 runs per case)
#   - each hand-written evals/behavior/<case>/ gets the shared graders: the skill fired, and (when telemetry.json
#     lists "manual" patterns) no command the skill's script owns was run by hand
#   - sandbox.sh (next to this script) is copied to evals/_lib/sandbox.sh for the behaviour scaffolds
# --stage-only builds the staged copy, prints its path and stops. Each case is a full Claude run on your own
# credential. Each run starts without your user skills, so a global skill's without arm is a true baseline. The
# behaviour cases run their scaffold scripts (authored in the repo) and need Bash, which this script
# grants. Exit code: the highest claude plugin eval exit code (0 every case scored 1.0, 1 some case below, 2 partial).
# Env: SKILL_TELEMETRY_DIR overrides the history directory.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/lib.sh"

usage() { sed -n '6,7p' "$0" | sed 's/^# //' >&2; exit 1; }

arg=""
if [[ "${1:-}" == --root ]]; then
  arg="$2"
  shift 2
fi
repo="$(skills_root "$arg")"
skills_layout "$repo"

target="${1:-}"
[[ -n "$target" ]] || usage
shift

args=()
tags=""
stage_only=no
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) args+=(--tag "$2"); tags="${tags:+$tags,}$2"; shift 2 ;;
    --case | --runs) args+=("$1" "$2"); shift 2 ;;
    --stage-only) stage_only=yes; shift ;;
    --) shift; args+=("$@"); break ;;
    *) echo "eval: unknown argument $1" >&2; exit 1 ;;
  esac
done

skill_grader() {
  printf -- '---\ntype: tool_used\ntool: Skill\ninput_match: %s\n' "'\"skill\"\\s*:\\s*\"(?:[\\w-]+:)?$1\"'"
  [[ "$2" == fire ]] || printf 'min: 0\nmax: 0\narm: both\n'
  printf -- '---\n'
}

# Copies the skill to $1 and generates the cases described in the header.
stage() {
  local skill="$1" src="$repo/$SKILLS_DIR/$1" dest="$2/$1"
  mkdir -p "$2"
  cp -R "$src" "$dest"
  rm -rf "$dest/evals/results" "$dest/evals/trigger" "$dest/evals/_lib"
  mkdir -p "$dest/evals/_lib"
  cp "$HERE/sandbox.sh" "$dest/evals/_lib/sandbox.sh"

  local triggers="$src/evals/triggers.json" kind key name case_dir
  if [[ -f "$triggers" ]]; then
    for kind in fire no-fire; do
      key="${kind/-/_}"
      while IFS= read -r name; do
        case_dir="$dest/evals/trigger/$kind/$name"
        mkdir -p "$case_dir/graders"
        jq -r --arg name "$name" --arg key "$key" --arg kind "$kind" '
          .[$key][] | select(.name == $name)
          | "---\ntags: [trigger, \($kind)]\nruns: 3\nmax_turns: 8\nallowed_tools: [Skill]\n---\n\n"
            + (if .context then .context + "\n\n" else "" end) + .prompt' "$triggers" >"$case_dir/prompt.md"
        skill_grader "$skill" "$kind" >"$case_dir/graders/skill-$kind.md"
      done < <(jq -r --arg key "$key" '.[$key][]?.name' "$triggers")
    done
  fi

  # The grader matches the whole tool input JSON ({"command":"...","description":"..."}), so a negated class such as
  # [^|;&] could run past the end of the command into the description. Excluding the double quote keeps each pattern
  # inside the command string. check.sh rejects .* and .+ in manual patterns for the same reason.
  local manual=""
  if [[ -f "$src/telemetry.json" ]]; then
    manual="$(jq -r '.manual // [] | map(gsub("\\[\\^"; "[^\"")) | join("|")' "$src/telemetry.json")"
  fi
  for case_dir in "$dest"/evals/behavior/*/; do
    [[ -f "$case_dir/prompt.md" ]] || continue
    mkdir -p "$case_dir/graders"
    [[ -f "$case_dir/graders/skill-fired.md" ]] || skill_grader "$skill" fire >"$case_dir/graders/skill-fired.md"
    if [[ -n "$manual" && ! -f "$case_dir/graders/no-manual.md" ]]; then
      jq -rn --arg re "\"command\"\\s*:\\s*\"[^\"]*($manual)" '
        "---\ntype: tool_used\ntool: Bash\ninput_match: \($re | @json)\nmin: 0\nmax: 0\nweight: 2\n---\n\n"
        + "The skill script runs these commands. The agent must not run them by hand (telemetry.json \"manual\")."' \
        >"$case_dir/graders/no-manual.md"
    fi
  done
}

skills=()
if [[ "$target" == --all ]]; then
  for d in "$repo/$SKILLS_DIR"/*/; do
    [[ -f "$d/SKILL.md" && -d "$d/evals" ]] && skills+=("$(basename "$d")")
  done
  [[ ${#skills[@]} -gt 0 ]] || { echo "eval: no skill has an evals/ directory" >&2; exit 1; }
else
  [[ "$target" != -* ]] || usage
  [[ -f "$repo/$SKILLS_DIR/$target/SKILL.md" ]] || { echo "eval: no skill at $SKILLS_DIR/$target" >&2; exit 1; }
  [[ -d "$repo/$SKILLS_DIR/$target/evals" ]] || { echo "eval: $SKILLS_DIR/$target has no evals/" >&2; exit 1; }
  skills=("$target")
fi

dir="${SKILL_TELEMETRY_DIR:-$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)/skill-telemetry}"
worst=0
for skill in "${skills[@]}"; do
  out="$repo/tmp/skill-evals/$skill/$(date -u +%Y%m%dT%H%M%SZ)"
  stage "$skill" "$out/stage"
  if [[ $stage_only == yes ]]; then
    echo "$out/stage/$skill"
    continue
  fi

  code=0
  claude plugin eval "$out/stage/$skill" --trust-plugin --scaffold --allow-tools Bash --no-publish \
    --output-dir "$out" --report "$out/report.html" ${args[@]+"${args[@]}"} || code=$?

  result="$out/aggregate-result.json"
  if [[ ! -f "$result" ]]; then
    echo "eval: $skill: no aggregate-result.json in $out (claude plugin eval exited $code)" >&2
    worst=$((code > worst ? code : (worst > 1 ? worst : 1)))
    continue
  fi
  mkdir -p "$dir"
  jq -c --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg skill "$skill" --arg tags "$tags" \
    --arg commit "$(git -C "$repo" rev-parse --short HEAD)" --arg result "$result" '
    {ts: $ts, skill: $skill, commit: $commit, tags: $tags,
     score: .aggregates.overallScore, passed: .aggregates.casesPassed, total: .aggregates.casesTotal,
     mean_delta: .aggregates.meanDelta, runs: ([.cases[].arms.with | length] | max // 0), cost_usd: .costUsd,
     partial: (.partial // false),
     cases: [.cases[] | {name, score: .aggregates.score, delta: .aggregates.delta}],
     result: $result}' "$result" >>"$dir/evals.jsonl"
  echo "eval: $skill: results in $out, history in $dir/evals.jsonl"
  worst=$((code > worst ? code : worst))
done
exit "$worst"
