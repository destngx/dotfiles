#!/usr/bin/env bash
# Tests for sandbox.sh: builds the demo repo the way a behaviour scaffold does, from a staged skill copy.
# Run: bash agents/tools/skills/sandbox.test.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(git -C "$HERE" rev-parse --show-toplevel)"
mkdir -p "$REPO/tmp"
ROOT="$(mktemp -d "$REPO/tmp/skills-sandbox-test.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT

failed=0
check() {
  if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: expected '$3', got '$2'"; failed=$((failed + 1)); fi
}

# Staged skill layout: <stage>/demo/{SKILL.md,scripts/run.sh,evals/_lib/sandbox.sh,evals/behavior/x/scaffold.sh}
skill="$ROOT/stage/demo"
mkdir -p "$skill/scripts" "$skill/evals/_lib" "$skill/evals/behavior/x" "$ROOT/ws" "$ROOT/home"
printf -- '---\nname: demo\ndescription: x\n---\n' >"$skill/SKILL.md"
printf '#!/usr/bin/env bash\n' >"$skill/scripts/run.sh"
cp "$HERE/sandbox.sh" "$skill/evals/_lib/sandbox.sh"
cat >"$skill/evals/behavior/x/scaffold.sh" <<'SCAFFOLD'
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../_lib/sandbox.sh"
sandbox_repo feat/demo
sandbox_advance_main other.txt "from main"
SCAFFOLD

(cd "$ROOT/ws" && HOME="$ROOT/home" bash "$skill/evals/behavior/x/scaffold.sh")
check "scaffold exits 0" "$?" 0
ws="$ROOT/ws"
check "worktree is on the branch" "$(git -C "$ws/wt" branch --show-current)" "feat/demo"
check "branch is one commit ahead of its base" "$(git -C "$ws/wt" rev-list --count HEAD ^"$(git -C "$ws/wt" merge-base HEAD origin/main)")" 1
check "skill is installed in the primary checkout" "$(test -f "$ws/primary/.agents/skills/demo/scripts/run.sh" && echo yes)" yes
check "evals are not installed" "$(test -e "$ws/primary/.agents/skills/demo/evals" && echo yes || echo no)" no
git -C "$ws/wt" fetch -q origin
check "main moved ahead of the branch" "$(git -C "$ws/wt" show origin/main:other.txt)" "from main"
if [[ "$(uname)" == Darwin && "$(command -v git)" == /usr/bin/git ]]; then
  check "real git copied into the temp home" "$("$ROOT/home/.nix-profile/bin/git" --version | cut -d' ' -f1-2)" "git version"
fi

[[ $failed -eq 0 ]]
