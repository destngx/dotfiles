#!/usr/bin/env zsh
# Tests for worktree.zsh (gwf). Each case builds a bare origin, a clone with a gwf worktree and a
# second clone that lands work on main, in a temporary directory, so nothing touches a real repo.
# Run: zsh git/worktree.test.zsh
# Shell options stay at zsh's defaults, as in the gwf executable, since gwf is sourced into this shell.

HERE=${0:A:h}
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/gwf-test.XXXXXX")
trap 'rm -rf -- "$ROOT"' EXIT

# Keep the user's git config, hooks and gwf trust file out of the tests.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 XDG_DATA_HOME=$ROOT/xdg
export GIT_TEMPLATE_DIR=$ROOT/templates
mkdir -p -- "$GIT_TEMPLATE_DIR"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
unset GWT_ROOT

source "$HERE/worktree.zsh"

passed=0
failed=0

fail() { print -r -- "  FAIL: $*"; failed=$((failed + 1)); return 1 }
assert_ok()      { (( $1 == 0 )) || fail "$2: expected exit 0, got $1" }
assert_not_ok()  { (( $1 != 0 )) || fail "$2: expected a nonzero exit" }
assert_dir()     { [[ -d $1 ]] || fail "$2: expected $1 to exist" }
assert_no_dir()  { [[ ! -e $1 ]] || fail "$2: expected $1 to be gone" }
assert_branch()  { command git -C "$T/clone" show-ref --verify --quiet "refs/heads/$1" || fail "$2: expected branch $1" }
assert_no_branch() { ! command git -C "$T/clone" show-ref --verify --quiet "refs/heads/$1" || fail "$2: expected branch $1 to be deleted" }

commit() { print -r -- "$3" >"$1/$2" && command git -C "$1" add -- "$2" && command git -C "$1" commit -qm "$2" }

# Sets up $T/origin.git, $T/clone (main) with worktree $WT on feat/topic holding two commits, and
# $T/up, a second clone that lands work on origin's main.
setup() {
  setopt local_options err_return
  T=$ROOT/$1
  WT=$T/clone-worktrees/topic
  mkdir -p -- "$T"
  command git init -q --bare -b main "$T/origin.git"
  command git clone -q "$T/origin.git" "$T/up" 2>/dev/null
  commit "$T/up" base.txt base
  command git -C "$T/up" push -q origin main
  command git clone -q "$T/origin.git" "$T/clone"
  (cd -- "$T/clone" && gwf create feat/topic) >/dev/null 2>&1
  commit "$WT" one.txt one
  commit "$WT" two.txt two
}

# Lands the branch's commits on origin's main under new commit IDs, after another commit, as a rebase
# merge does. The clone has not fetched since.
land_rebased() {
  setopt local_options err_return
  commit "$T/up" other.txt other
  command git -C "$T/up" fetch -q "$T/clone" feat/topic
  command git -C "$T/up" cherry-pick origin/main..FETCH_HEAD >/dev/null
  command git -C "$T/up" push -q origin main
}

rm_branch() { (cd -- "$T/clone" && gwf rm -y -D topic) >"$T/out" 2>&1 }

run() {
  local name=$1
  print -r -- "- $name"
  local before=$failed
  if "test_$name"; then
    passed=$((passed + 1))
  else
    (( failed > before )) || fail "test_$name stopped early"
    print -r -- "    output: $(cat -- "$T/out" 2>/dev/null)"
  fi
}

test_rebase_merged_branch_is_removed() {
  setup rebased
  land_rebased
  local rc=0; rm_branch || rc=$?
  assert_ok $rc "gwf rm -y -D" &&
    assert_no_dir "$WT" "worktree" &&
    assert_no_branch feat/topic "local branch"
}

test_branch_with_unmerged_commit_is_kept() {
  setup unmerged
  land_rebased
  commit "$WT" three.txt three
  local rc=0; rm_branch || rc=$?
  assert_not_ok $rc "gwf rm -y -D" &&
    assert_dir "$WT" "worktree" &&
    { [[ -f $WT/three.txt ]] || fail "worktree files: expected three.txt to stay" } &&
    assert_branch feat/topic "local branch"
}

test_fast_forward_merged_branch_is_removed() {
  setup fast-forward
  command git -C "$WT" push -q origin HEAD:main
  local rc=0; rm_branch || rc=$?
  assert_ok $rc "gwf rm -y -D" &&
    assert_no_dir "$WT" "worktree" &&
    assert_no_branch feat/topic "local branch"
}

run rebase_merged_branch_is_removed
run branch_with_unmerged_commit_is_kept
run fast_forward_merged_branch_is_removed

print "$passed passed, $failed failed"
(( failed == 0 ))
