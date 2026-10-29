#!/usr/bin/env bash
# Tests for report.sh against a fixture events log and a fixture repo with one skill (rebase-merge).
# Run: bash agents/tools/skills/report.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT="$HERE/report.sh"
REPO_TMP="$(git -C "$HERE" rev-parse --show-toplevel)/tmp"
mkdir -p "$REPO_TMP"
T="$(mktemp -d "$REPO_TMP/skills-report-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT

FIXTURE="$T/repo"
mkdir -p "$FIXTURE/.agents/skills/rebase-merge/scripts"
git init -q "$FIXTURE"
printf -- '---\nname: rebase-merge\ndescription: x\n---\n' >"$FIXTURE/.agents/skills/rebase-merge/SKILL.md"
printf '{"phrases": ["merge"], "script": "scripts/rebase-merge.sh", "steps": ["prepare", "land", "cleanup"]}\n' \
  >"$FIXTURE/.agents/skills/rebase-merge/telemetry.json"

passed=0
failed=0

check() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    passed=$((passed + 1))
    echo "ok   $name"
  else
    failed=$((failed + 1))
    echo "FAIL $name: expected '$want', got '$got'"
  fi
}

cat >"$T/events.jsonl" <<'EOF'
{"ts":"2026-10-20T10:00:00Z","session":"a","event":"prompt","skill":"rebase-merge","phrase":"merge rebase","text":"merge rebase it"}
{"ts":"2026-10-20T10:00:20Z","session":"a","event":"skill","skill":"rebase-merge","repo":true}
{"ts":"2026-10-20T10:01:00Z","session":"a","event":"step","skill":"rebase-merge","step":"prepare","exit":0,"out":{}}
{"ts":"2026-10-20T10:02:00Z","session":"a","event":"step","skill":"rebase-merge","step":"land","exit":0,"out":{}}
{"ts":"2026-10-20T10:09:00Z","session":"a","event":"step","skill":"rebase-merge","step":"cleanup","exit":0,"out":{}}
{"ts":"2026-10-21T09:00:00Z","session":"b","event":"prompt","skill":"rebase-merge","phrase":"proceed merge","text":"proceed merge"}
{"ts":"2026-10-21T09:30:00Z","session":"b","event":"skill","skill":"rebase-merge","repo":true}
{"ts":"2026-10-21T09:31:00Z","session":"b","event":"step","skill":"rebase-merge","step":"prepare","exit":3,"out":{"conflict":"a.txt"}}
{"ts":"2026-10-21T09:32:00Z","session":"b","event":"manual","skill":"rebase-merge","pattern":"x","command":"git rebase --continue"}
{"ts":"2026-10-21T12:00:00Z","session":"d","event":"prompt","skill":"rebase-merge","phrase":"merge","text":"merge"}
{"ts":"2026-10-21T12:00:20Z","session":"d","event":"step","skill":"rebase-merge","step":"prepare","exit":0,"out":{}}
{"ts":"2026-10-22T08:01:00Z","session":"c","event":"skill","skill":"unslop","repo":false}
EOF
cat >"$T/evals.jsonl" <<'EOF'
{"ts":"2026-10-23T08:00:00Z","skill":"rebase-merge","score":0.9,"passed":9,"total":10,"runs":1,"cost_usd":1.2,"tags":""}
EOF

r="$(SKILL_TELEMETRY_DIR="$T" bash "$REPORT" --root "$FIXTURE" --skill rebase-merge --json)"
s() { jq -r ".skills[0] | $1" <<<"$r"; }

check "counts model invocations" "$(s '.fired')" "2"
check "phrase prompt followed by a script step (skill loaded earlier) is not a miss" "$(s '.possible_misses | map(.session) | index("d") // "none"')" "none"
check "phrase prompt with a late call is a possible miss" "$(s '.possible_misses | map(.session) | join(",")')" "b"
check "model call long after its phrase is unprompted" "$(s '.unprompted_calls | map(.session) | join(",")')" "b"
check "a session that reached cleanup counts as completed" "$(s '"\(.sessions_with_steps) \(.completed)"')" "3 1"
check "exit codes per step" "$(s '.exit_codes.prepare | tostring')" '{"0":2,"3":1}'
check "step sequence per session" "$(s '.runs | map(.steps) | join(" | ")')" "prepare:0 land:0 cleanup:0 | prepare:3 | prepare:0"
check "manual commands" "$(s '.manual | map(.command) | join(",")')" "git rebase --continue"
check "latest evals" "$(s '.evals[0].score')" "0.9"

r="$(SKILL_TELEMETRY_DIR="$T" bash "$REPORT" --root "$FIXTURE" --skill rebase-merge --since 2026-10-22 --json)"
check "--since drops older events" "$(s '"\(.fired) \(.phrase_prompts)"')" "0 0"

text="$(SKILL_TELEMETRY_DIR="$T" bash "$REPORT" --root "$FIXTURE" --skill rebase-merge)"
check "text report names the skill" "$(head -1 <<<"$text")" "== rebase-merge  (since 1970-01-01)"

SKILL_TELEMETRY_DIR="$T/empty" bash "$REPORT" --root "$FIXTURE" >/dev/null 2>&1
check "missing log is not an error" "$?" "0"

SKILL_TELEMETRY_DIR="$T" bash "$REPORT" --root "$FIXTURE" --since yesterday >/dev/null 2>&1
check "bad --since is rejected" "$?" "1"

echo
echo "$passed passed, $failed failed"
[[ $failed -eq 0 ]]
