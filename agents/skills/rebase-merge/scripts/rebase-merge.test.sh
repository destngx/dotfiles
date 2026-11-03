#!/usr/bin/env bash
# Tests for rebase-merge.sh. Each case builds a bare origin, a primary checkout on main and a feature worktree in a
# temporary directory, with stub gh, vercel, gwf and pnpm binaries on PATH, so nothing touches the real remote.
# Run: bash ~/.agents/skills/rebase-merge/scripts/rebase-merge.test.sh
set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rebase-merge.sh"
REPO_TMP="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)/tmp"
mkdir -p "$REPO_TMP"
ROOT="$(mktemp -d "$REPO_TMP/rebase-merge-test.XXXXXX")"
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

# Sets up $T/origin.git, $T/primary (main) and $T/wt (branch feat/x with one commit) and stub binaries in $T/bin.
setup() {
  T="$ROOT/$1"
  mkdir -p "$T/bin"
  git init -q --bare -b main "$T/origin.git"
  git clone -q "$T/origin.git" "$T/primary" 2>/dev/null
  git -C "$T/primary" config user.email test@example.com
  git -C "$T/primary" config user.name test
  git -C "$T/primary" config core.hooksPath /dev/null
  echo base >"$T/primary/base.txt"
  echo sums >"$T/primary/go.work.sum"
  mkdir -p "$T/primary/apps/site"
  echo '{}' >"$T/primary/apps/site/vercel.json"
  git -C "$T/primary" add -A
  git -C "$T/primary" commit -qm "chore: base"
  git -C "$T/primary" push -q origin main
  git -C "$T/primary" worktree add -q -b feat/x "$T/wt" origin/main 2>/dev/null
  echo feature >"$T/wt/feature.txt"
  git -C "$T/wt" add -A
  git -C "$T/wt" commit -qm "feat: x"

  # gh: no PR unless $T/pr-state exists.
  cat >"$T/bin/gh" <<EOF
#!/usr/bin/env bash
[[ -f "$T/pr-state" ]] || { echo 'no pull requests found' >&2; exit 1; }
echo "\$(cat "$T/pr-state") https://example.test/pr/1"
EOF
  # vercel: answers ls from $T/vercel-state (missing file means no deployment yet), logs a line per call.
  cat >"$T/bin/vercel" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$T/vercel-calls"
case "\$1" in
  ls)
    if [[ -f "$T/vercel-state" ]]; then
      printf '{"deployments":[{"url":"site-abc.vercel.app","state":"%s"}]}\n' "\$(cat "$T/vercel-state")"
    else
      echo '{"deployments":[]}'
    fi
    ;;
  inspect)
    [[ "\$*" == *--logs* ]] && echo "build log line"
    exit 0
    ;;
esac
EOF
  # gwf: only "rm -y -D <branch>", implemented with plain git; refuses when $T/in-use exists.
  cat >"$T/bin/gwf" <<EOF
#!/usr/bin/env bash
[[ "\$1 \$2 \$3" == "rm -y -D" ]] || { echo "unexpected gwf \$*" >&2; exit 1; }
if [[ -f "$T/in-use" ]]; then printf 'gwf: skipping %s, in use by:\n    node (pid %s)\n' "$T/wt" "\$(cat "$T/in-use")"; exit 0; fi
git worktree remove "$T/wt" && git branch -d "\$4" && git worktree prune
EOF
  cat >"$T/bin/pnpm" <<EOF
#!/usr/bin/env bash
echo "\$*" >>"$T/pnpm-calls"
EOF
  chmod +x "$T/bin/"*
}

# Runs the script with the stubs first on PATH. Sets $out and $code.
run() {
  local dir="$1"
  shift
  out="$(cd "$dir" && PATH="$T/bin:$PATH" REBASE_MERGE_POLL_SECONDS=1 REBASE_MERGE_DEPLOY_TIMEOUT=2 \
    bash "$SCRIPT" "$@" 2>&1)"
  code=$?
}

# Adds a commit on origin/main from a scratch clone, so the branch falls behind.
advance_main() {
  local file="$1" content="$2"
  git clone -q "$T/origin.git" "$T/scratch-$file" 2>/dev/null
  git -C "$T/scratch-$file" -c user.email=t@e -c user.name=t -c core.hooksPath=/dev/null \
    commit -q --allow-empty -m "chore: bump" 2>/dev/null
  echo "$content" >"$T/scratch-$file/$file"
  git -C "$T/scratch-$file" add -A
  git -C "$T/scratch-$file" -c user.email=t@e -c user.name=t -c core.hooksPath=/dev/null commit -qm "chore: $file"
  git -C "$T/scratch-$file" push -q origin main
}

test_prepare_pushes_branch_without_rewrite() {
  setup prepare-plain
  run "$T/wt" prepare
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "rewritten=no" "rewrite flag" || return
  assert_contains "$out" "commits=1" "commit count" || return
  assert_eq "$(git -C "$T/wt" rev-parse feat/x)" "$(git -C "$T/origin.git" rev-parse feat/x)" "pushed tip"
}

test_prepare_reports_rewrite_when_main_moved() {
  setup prepare-rewrite
  advance_main other.txt other
  run "$T/wt" prepare
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "rewritten=yes" "rewrite flag" || return
  git -C "$T/wt" merge-base --is-ancestor origin/main feat/x || fail "branch not on top of main"
}

test_prepare_refuses_dirty_worktree() {
  setup prepare-dirty
  echo wip >"$T/wt/wip.txt"
  run "$T/wt" prepare
  assert_eq "$code" 2 "exit code" || return
  assert_contains "$out" "wip.txt" "lists the dirty file"
}

test_prepare_discards_go_work_sum() {
  setup prepare-go-work-sum
  echo downloaded >>"$T/wt/go.work.sum"
  run "$T/wt" prepare
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "discarded=$T/wt/go.work.sum" "reports the discard" || return
  assert_eq "$(cat "$T/wt/go.work.sum")" "sums" "restored file"
}

test_prepare_aborts_on_conflict() {
  setup prepare-conflict
  advance_main feature.txt "main version"
  run "$T/wt" prepare
  assert_eq "$code" 3 "exit code" || return
  assert_contains "$out" "conflict=feature.txt" "lists the conflicting file" || return
  [[ ! -d "$(git -C "$T/wt" rev-parse --git-path rebase-merge)" ]] || fail "rebase left in progress"
}

test_prepare_refuses_branch_without_commits() {
  setup prepare-empty
  git -C "$T/wt" reset -q --hard origin/main
  run "$T/wt" prepare
  assert_eq "$code" 2 "exit code" || return
  assert_contains "$out" "nothing to land" "message"
}

test_prepare_finds_worktree_by_branch_name() {
  setup prepare-by-name
  run "$T/primary" prepare feat/x
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "worktree=$T/wt" "worktree path"
}

test_prepare_refuses_main() {
  setup prepare-main
  run "$T/primary" prepare main
  assert_eq "$code" 2 "exit code"
}

# Pushes branch <name> to origin, one commit ahead of main, from a scratch clone.
add_origin_branch() {
  local name="$1"
  git clone -q "$T/origin.git" "$T/scratch-$name" 2>/dev/null
  git -C "$T/scratch-$name" checkout -q -b "$name"
  echo "$name" >"$T/scratch-$name/$name.txt"
  git -C "$T/scratch-$name" add -A
  git -C "$T/scratch-$name" -c user.email=t@e -c user.name=t -c core.hooksPath=/dev/null commit -qm "chore: $name"
  git -C "$T/scratch-$name" push -q origin "$name"
}

test_land_and_cleanup_on_a_non_main_base() {
  setup base-release
  add_origin_branch release
  run "$T/wt" prepare --base release
  assert_eq "$code" 0 "exit code of prepare" || return
  assert_contains "$out" "base=release" "base line" || return
  assert_contains "$out" "rewritten=yes" "rebased onto release" || return
  local main_before
  main_before="$(git -C "$T/origin.git" rev-parse main)"
  run "$T/wt" land feat/x --base release
  assert_eq "$code" 0 "exit code of land" || return
  assert_eq "$(git -C "$T/origin.git" rev-parse release)" "$(git -C "$T/wt" rev-parse feat/x)" "origin release tip" || return
  assert_eq "$(git -C "$T/origin.git" rev-parse main)" "$main_before" "origin main unchanged" || return
  assert_contains "$out" "old_main=$(git -C "$T/origin.git" rev-parse release~1)" "old base tip" || return
  run "$T/primary" cleanup feat/x
  assert_eq "$code" 6 "cleanup against main refuses the branch" || return
  run "$T/primary" cleanup feat/x --base release
  assert_eq "$code" 0 "exit code of cleanup" || return
  [[ ! -d "$T/wt" ]] || fail "worktree still exists" || return
  assert_contains "$out" "pulled=skipped (primary checkout is on main)" "no pull off the base"
}

test_base_defaults_to_origin_head() {
  setup base-origin-head
  add_origin_branch trunk
  git -C "$T/origin.git" symbolic-ref HEAD refs/heads/trunk
  git -C "$T/primary" fetch -q origin
  git -C "$T/primary" remote set-head origin -a >/dev/null
  run "$T/wt" prepare
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "base=trunk" "base line" || return
  git -C "$T/wt" merge-base --is-ancestor origin/trunk feat/x || fail "branch not on top of trunk"
}

test_base_falls_back_to_main_without_origin_head() {
  setup base-no-origin-head
  # The setup clones origin while it is empty, so origin/HEAD is not set.
  ! git -C "$T/primary" symbolic-ref -q refs/remotes/origin/HEAD >/dev/null || fail "origin/HEAD is set" || return
  run "$T/wt" prepare
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "base=main" "base line"
}

test_prepare_refuses_missing_base() {
  setup base-missing
  run "$T/wt" prepare --base nope
  assert_eq "$code" 2 "exit code" || return
  assert_contains "$out" "origin has no branch nope" "message"
}

test_base_option_needs_a_value() {
  setup base-no-value
  run "$T/wt" land --base
  assert_eq "$code" 1 "exit code"
}

test_land_fast_forwards_main() {
  setup land-ok
  echo MERGED >"$T/pr-state"
  run "$T/wt" prepare
  run "$T/wt" land
  assert_eq "$code" 0 "exit code" || return
  assert_eq "$(git -C "$T/origin.git" rev-parse main)" "$(git -C "$T/wt" rev-parse feat/x)" "origin main tip" || return
  assert_contains "$out" "pr_state=MERGED" "PR state" || return
  assert_contains "$out" "vercel_apps=apps/site" "vercel apps" || return
  assert_eq "$(git -C "$T/wt" branch --show-current)" "feat/x" "worktree still on the branch"
}

test_land_without_pr() {
  setup land-no-pr
  run "$T/wt" prepare
  run "$T/wt" land
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "pr_state=none" "PR state"
}

test_land_reports_main_moved() {
  setup land-moved
  run "$T/wt" prepare
  advance_main other.txt other
  run "$T/wt" land
  assert_eq "$code" 4 "exit code" || return
  assert_contains "$out" "rerun prepare" "message"
}

# GitHub answers a push that loses a race with another push to main with "cannot lock ref", not "non-fast-forward".
# The hook moves main while the push holds the ref, which makes local git answer the same way.
test_land_reports_main_moved_when_ref_lock_races() {
  setup land-lock-race
  run "$T/wt" prepare
  advance_main other.txt other
  git -C "$T/origin.git" update-ref refs/heads/raced "$(git -C "$T/origin.git" rev-parse main)"
  git -C "$T/origin.git" update-ref refs/heads/main "$(git -C "$T/origin.git" rev-parse main~2)"
  git -C "$T/origin.git" config core.hooksPath "$T/origin.git/hooks"
  cat >"$T/origin.git/hooks/pre-receive" <<'HOOK'
#!/usr/bin/env bash
env -u GIT_QUARANTINE_PATH git update-ref refs/heads/main refs/heads/raced
HOOK
  chmod +x "$T/origin.git/hooks/pre-receive"
  run "$T/wt" land
  assert_eq "$code" 4 "exit code" || return
  assert_contains "$out" "rerun prepare" "message"
}

test_land_refuses_unpushed_branch() {
  setup land-unpushed
  run "$T/wt" land
  assert_eq "$code" 2 "exit code" || return
  assert_contains "$out" "run prepare" "message"
}

test_deploy_ready() {
  setup deploy-ready
  echo READY >"$T/vercel-state"
  run "$T/wt" deploy
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "deploy.apps/site=READY https://site-abc.vercel.app" "deploy line" || return
  assert_contains "$(cat "$T/vercel-calls")" "ls site --prod -m githubCommitSha=" "looks up by SHA"
}

test_deploy_canceled_counts_as_skipped() {
  setup deploy-canceled
  echo CANCELED >"$T/vercel-state"
  run "$T/wt" deploy
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "deploy.apps/site=SKIPPED" "deploy line"
}

test_deploy_error_prints_logs() {
  setup deploy-error
  echo ERROR >"$T/vercel-state"
  run "$T/wt" deploy
  assert_eq "$code" 7 "exit code" || return
  assert_contains "$out" "deploy.apps/site=ERROR" "deploy line" || return
  assert_contains "$out" "build log line" "logs"
}

test_deploy_times_out_without_deployment() {
  setup deploy-missing
  run "$T/wt" deploy
  assert_eq "$code" 7 "exit code" || return
  assert_contains "$out" "deploy.apps/site=NOT_FOUND" "deploy line"
}

test_cleanup_removes_worktree_and_branches() {
  setup cleanup-ok
  run "$T/wt" prepare
  run "$T/wt" land
  run "$T/primary" cleanup feat/x
  assert_eq "$code" 0 "exit code" || return
  [[ ! -d "$T/wt" ]] || fail "worktree still exists" || return
  ! git -C "$T/primary" show-ref -q --verify refs/heads/feat/x || fail "local branch still exists" || return
  ! git -C "$T/origin.git" show-ref -q --verify refs/heads/feat/x || fail "remote branch still exists" || return
  assert_contains "$(cat "$T/pnpm-calls")" "exec nx daemon --stop" "stops the Nx daemon" || return
  assert_contains "$out" "pulled=yes" "pull" || return
  assert_eq "$(git -C "$T/primary" rev-parse main)" "$(git -C "$T/origin.git" rev-parse main)" "primary main updated"
}

test_cleanup_skips_pull_when_primary_dirty() {
  setup cleanup-dirty-primary
  run "$T/wt" prepare
  run "$T/wt" land
  echo other-session >"$T/primary/wip.txt"
  run "$T/primary" cleanup feat/x
  assert_eq "$code" 0 "exit code" || return
  assert_contains "$out" "pulled=skipped" "pull skipped"
}

test_cleanup_pulls_when_primary_has_only_go_work_sum() {
  setup cleanup-go-work-sum
  run "$T/wt" prepare
  run "$T/wt" land
  echo downloaded >>"$T/wt/go.work.sum"
  echo downloaded >>"$T/primary/go.work.sum"
  run "$T/primary" cleanup feat/x
  assert_eq "$code" 0 "exit code" || return
  [[ ! -d "$T/wt" ]] || fail "worktree still exists" || return
  assert_contains "$out" "pulled=yes" "pull" || return
  assert_eq "$(cat "$T/primary/go.work.sum")" "sums" "restored file"
}

test_cleanup_refuses_unmerged_branch() {
  setup cleanup-unmerged
  run "$T/wt" prepare
  run "$T/primary" cleanup feat/x
  assert_eq "$code" 6 "exit code" || return
  [[ -d "$T/wt" ]] || fail "worktree removed"
}

test_cleanup_reports_worktree_in_use() {
  setup cleanup-in-use
  run "$T/wt" prepare
  run "$T/wt" land
  (cd "$T/wt" && exec sleep 30) &
  local pid=$!
  echo "$pid" >"$T/in-use"
  run "$T/primary" cleanup feat/x
  kill "$pid"
  assert_eq "$code" 8 "exit code" || return
  assert_contains "$out" "in use by:" "gwf message" || return
  assert_contains "$out" "in_use=$pid cwd=$(cd "$T/wt" && pwd -P) command=sleep 30" "process details" || return
  git -C "$T/origin.git" show-ref -q --verify refs/heads/feat/x || fail "remote branch deleted before the worktree"
}

test_cleanup_succeeds_when_remote_branch_already_gone() {
  setup cleanup-remote-gone
  run "$T/wt" prepare
  run "$T/wt" land
  git -C "$T/origin.git" update-ref -d refs/heads/feat/x # deleted on the server, as GitHub does after a merge
  run "$T/primary" cleanup feat/x
  assert_eq "$code" 0 "exit code" || return
  [[ ! -d "$T/wt" ]] || fail "worktree still exists" || return
  assert_contains "$out" "remote_branch_deleted=feat/x" "remote line" || return
  assert_contains "$out" "pulled=yes" "pull"
}

# A cleanup that stopped after deleting the local branch can run again to delete the remote one.
test_cleanup_resumes_when_only_remote_branch_is_left() {
  setup cleanup-resume
  run "$T/wt" prepare
  run "$T/wt" land
  git -C "$T/primary" worktree remove "$T/wt"
  git -C "$T/primary" branch -q -D feat/x
  run "$T/primary" cleanup feat/x
  assert_eq "$code" 0 "exit code" || return
  ! git -C "$T/origin.git" show-ref -q --verify refs/heads/feat/x || fail "remote branch still exists" || return
  assert_contains "$out" "pulled=yes" "pull"
}

test_cleanup_refuses_unknown_branch() {
  setup cleanup-unknown
  run "$T/primary" cleanup feat/nope
  assert_eq "$code" 2 "exit code" || return
  assert_contains "$out" "no branch feat/nope" "message"
}

test_cleanup_reports_rejected_remote_delete() {
  setup cleanup-delete-rejected
  run "$T/wt" prepare
  run "$T/wt" land
  git -C "$T/origin.git" config core.hooksPath "$T/origin.git/hooks"
  cat >"$T/origin.git/hooks/pre-receive" <<'HOOK'
#!/usr/bin/env bash
while read -r _ new _; do [[ "$new" =~ ^0+$ ]] && { echo "deletes are not allowed" >&2; exit 1; }; done
exit 0
HOOK
  chmod +x "$T/origin.git/hooks/pre-receive"
  run "$T/primary" cleanup feat/x
  assert_eq "$code" 5 "exit code" || return
  [[ "$out" != *"remote_branch_deleted="* ]] || fail "claimed the remote branch was deleted" || return
  git -C "$T/origin.git" show-ref -q --verify refs/heads/feat/x || fail "remote branch deleted"
}

# The bug this guards: a failed ls-remote (here a killed ssh, exit 128) was read as "no remote branch".
test_cleanup_stops_when_remote_check_fails() {
  setup cleanup-ls-remote-fails
  run "$T/wt" prepare
  run "$T/wt" land
  cat >"$T/bin/git" <<STUB
#!/usr/bin/env bash
[[ "\$1" != ls-remote ]] || { echo "fatal: Could not read from remote repository." >&2; exit 128; }
exec "$(command -v git)" "\$@"
STUB
  chmod +x "$T/bin/git"
  run "$T/primary" cleanup feat/x
  assert_eq "$code" 1 "exit code" || return
  assert_contains "$out" "git ls-remote exited 128" "message" || return
  [[ "$out" != *"remote_branch_deleted="* ]] || fail "claimed the remote branch was deleted" || return
  git -C "$T/origin.git" show-ref -q --verify refs/heads/feat/x || fail "remote branch deleted"
}

# Stubs ssh on PATH so origin over SSH fails like an unreachable host, logging each call to $T/ssh-calls.
stub_unreachable_ssh_origin() {
  git -C "$T/primary" remote set-url origin ssh://git@example.invalid/repo.git
  cat >"$T/bin/$1" <<STUB
#!/usr/bin/env bash
echo "$1 \$*" >>"$T/ssh-calls"
echo "ssh: connect to host example.invalid: Operation timed out" >&2
exit 255
STUB
  chmod +x "$T/bin/$1"
}

test_cleanup_fails_when_origin_unreachable() {
  setup cleanup-unreachable
  run "$T/wt" prepare
  run "$T/wt" land
  stub_unreachable_ssh_origin ssh
  out="$(cd "$T/primary" && PATH="$T/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null bash "$SCRIPT" cleanup feat/x 2>&1)"
  code=$?
  [[ "$code" != 0 ]] || fail "exit code 0" || return
  [[ "$out" != *"_deleted="* ]] || fail "claimed a branch was deleted: $out" || return
  [[ -d "$T/wt" ]] || fail "worktree removed" || return
  assert_contains "$(cat "$T/ssh-calls")" "ConnectTimeout=" "ssh connect timeout" || return
  assert_contains "$(cat "$T/ssh-calls")" "ServerAliveInterval=" "ssh keepalive"
}

test_keeps_user_ssh_command() {
  setup ssh-command-kept
  stub_unreachable_ssh_origin my-ssh
  (cd "$T/primary" && PATH="$T/bin:$PATH" GIT_SSH_COMMAND=my-ssh bash "$SCRIPT" cleanup feat/x >/dev/null 2>&1)
  assert_contains "$(cat "$T/ssh-calls")" "my-ssh" "uses the user's command" || return
  [[ "$(cat "$T/ssh-calls")" != *ConnectTimeout* ]] || fail "replaced GIT_SSH_COMMAND"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  echo "$t"
  if "$t"; then passed=$((passed + 1)); fi
done
echo "passed=$passed failed=$failed"
[[ $failed -eq 0 ]]
