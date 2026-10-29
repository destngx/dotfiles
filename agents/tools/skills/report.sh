#!/usr/bin/env bash
# Summarises the skill telemetry that hook.sh writes and the eval history that eval.sh writes, per skill of the git
# repo of the current directory (or --root):
# how often the model invoked it, prompts that matched a trigger phrase but were not followed by a call or a script
# step (possible misses), model calls with no trigger phrase (possible over-triggering), its script steps with exit codes, how many
# sessions reached the last step, commands run by hand that the script owns, and the latest eval scores.
#
# Usage: bash ~/.agents/tools/skills/report.sh [--root <repo root>] [--skill <name>] [--since <YYYY-MM-DD>] [--json]
# Env: SKILL_TELEMETRY_DIR overrides the log directory (default: <git common dir>/skill-telemetry).
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

root=""
skill=""
since="1970-01-01"
json=no
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) root="$2"; shift 2 ;;
    --skill) skill="$2"; shift 2 ;;
    --since) since="$2"; shift 2 ;;
    --json) json=yes; shift ;;
    -h | --help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "report: unknown argument $1" >&2; exit 1 ;;
  esac
done
[[ "$since" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || { echo "report: --since takes YYYY-MM-DD, got $since" >&2; exit 1; }

repo="$(skills_root "$root")"
skills_layout "$repo"
dir="${SKILL_TELEMETRY_DIR:-$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)/skill-telemetry}"

catalog="$(for d in "$repo/$SKILLS_DIR"/*/; do
  [[ -f "$d/SKILL.md" ]] || continue
  telemetry='{}'
  [[ -f "$d/telemetry.json" ]] && telemetry="$(cat "$d/telemetry.json")"
  jq -nc --arg name "$(basename "$d")" --argjson t "$telemetry" \
    --argjson has_telemetry "$([[ -f "$d/telemetry.json" ]] && echo true || echo false)" \
    --argjson has_evals "$([[ -f "$d/evals/triggers.json" ]] && echo true || echo false)" \
    '{name: $name, has_telemetry: $has_telemetry, has_evals: $has_evals} + $t'
done | jq -sc .)"

read_jsonl() { if [[ -f "$1" ]]; then jq -c . "$1"; fi; }
events="$(read_jsonl "$dir/events.jsonl" | jq -sc .)"
evals="$(read_jsonl "$dir/evals.jsonl" | jq -sc .)"
hook_errors="$(if [[ -f "$dir/hook-errors.log" ]]; then wc -l <"$dir/hook-errors.log" | tr -d ' '; else echo 0; fi)"

# A model Skill call within this many seconds after a phrase prompt in the same session counts as that prompt firing.
WINDOW=600

summary="$(jq -n --argjson catalog "$catalog" --argjson events "$events" --argjson evals "$evals" \
  --arg skill "$skill" --arg since "${since}T00:00:00Z" --argjson window "$WINDOW" --argjson hook_errors "$hook_errors" '
  def t: .ts | fromdateiso8601;
  ($events | map(select(.ts >= $since))) as $ev
  | {
      hook_errors: $hook_errors,
      skills: [
        $catalog[] | select($skill == "" or .name == $skill) | . as $s
        | ($ev | map(select(.skill == $s.name))) as $mine
        | ($mine | map(select(.event == "skill"))) as $calls
        | ($mine | map(select(.event == "prompt"))) as $phrases
        | ($mine | map(select(.event == "step"))) as $steps
        | ($steps | group_by(.session)) as $runs
        | {
            name: $s.name,
            has_telemetry: $s.has_telemetry,
            has_evals: $s.has_evals,
            has_script: ($s.script != null),
            fired: ($calls | length),
            phrase_prompts: ($phrases | length),
            possible_misses: [
              $phrases[] | . as $p
              # A script step counts as firing too: when the skill is already loaded in the session, the model runs
              # the script again without calling the Skill tool.
              | select(any($calls[], $steps[]; .session == $p.session and (t - ($p | t)) >= 0 and (t - ($p | t)) <= $window) | not)
              | {ts, session, phrase, text}
            ],
            unprompted_calls: [
              $calls[] | . as $c
              | select(any($phrases[]; .session == $c.session and (($c | t) - t) >= 0 and (($c | t) - t) <= $window) | not)
              | {ts, session, args}
            ],
            sessions_with_steps: ($runs | length),
            completed: ($runs | map(select(any(.[]; .step == ($s.steps | last) and .exit == 0))) | length),
            exit_codes: ($steps | group_by(.step) | map({key: .[0].step, value: (group_by(.exit) | map({key: (.[0].exit | tostring), value: length}) | from_entries)}) | from_entries),
            runs: [$runs[] | {session: .[0].session, ts: .[0].ts, steps: map("\(.step):\(.exit)") | join(" ")}],
            manual: [$mine[] | select(.event == "manual") | {ts, session, command}],
            evals: [$evals[] | select(.skill == $s.name)] | sort_by(.ts) | .[-5:]
          }
      ]
    }')"

if [[ $json == yes ]]; then
  echo "$summary"
  exit 0
fi

jq -r --arg since "$since" '
  def list(f): if length == 0 then "    none" else map("    " + f) | join("\n") end;
  (.skills[] |
    "== \(.name)  (since \($since))",
    (if .has_telemetry then empty else "  no telemetry.json: trigger phrases and script steps are not tracked" end),
    (if .has_evals then empty else "  no evals/triggers.json: run bash ~/.agents/tools/skills/new.sh \(.name) to add one" end),
    "  fired: \(.fired) times",
    "  trigger-phrase prompts: \(.phrase_prompts), possible misses (phrase matched, no skill call or script step within 10 min): \(.possible_misses | length)",
    (.possible_misses | list("\(.ts) [\(.phrase)] \(.text)")),
    "  model calls with no trigger phrase before them: \(.unprompted_calls | length)",
    (.unprompted_calls | list("\(.ts) session \(.session[:8]) \(.args // "")")),
    (if .has_script then
    "  sessions that ran the script: \(.sessions_with_steps), reached the last step with exit 0: \(.completed)",
    "  exit codes per step: \(.exit_codes | to_entries | map("\(.key) \(.value | to_entries | map("\(.key)x\(.value)") | join(","))") | join("  ") | if . == "" then "none" else . end)",
    (.runs | list("\(.ts) session \(.session[:8]): \(.steps)")),
    "  commands run by hand that the script owns: \(.manual | length)",
    (.manual | list("\(.ts) session \(.session[:8]): \(.command)"))
    else empty end),
    "  latest evals:",
    (.evals | list("\(.ts) score \(.score) (\(.passed)/\(.total) cases) runs \(.runs) cost $\(.cost_usd)\(if .tags != "" then " tags " + .tags else "" end)")),
    ""),
  (if .hook_errors > 0 then "hook errors: \(.hook_errors) (see hook-errors.log in the telemetry dir)" else empty end)
' <<<"$summary"
