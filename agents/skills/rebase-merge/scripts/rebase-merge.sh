#!/usr/bin/env bash
# Mechanical steps of the rebase-merge skill. Each subcommand prints key=value lines on stdout, messages on stderr,
# and stops with a distinct exit code so the agent only has to make the judgement calls between steps.
#
#   prepare [branch] [--base BRANCH]   rebase the branch's worktree onto origin/<base> and push the branch
#   land [branch] [--base BRANCH]      fast-forward origin/<base> to the pushed branch and verify it
#   deploy [sha]                       wait for the production deploy of every app with a vercel.json
#                                      (default: the tip of origin's default branch)
#   cleanup <branch> [--base BRANCH]   remove the merged branch's worktree, local and remote branch, then pull the
#                                      primary checkout
#
# The base defaults to origin's default branch (refs/remotes/origin/HEAD), or main when origin/HEAD is not set.
# prepare, land and cleanup print base=<branch> first. The keys old_main and main hold the base's old and new tips.
#
# Exit codes:
#   0 done            1 usage or unexpected error   2 precondition not met   3 rebase conflict
#   4 base moved      5 push rejected                6 verification failed    7 deploy failed or missing
#   8 cleanup refused (worktree dirty or in use)
#
# Env: REBASE_MERGE_POLL_SECONDS (default 10), REBASE_MERGE_DEPLOY_TIMEOUT (seconds per app, default 600),
# REBASE_MERGE_PR_TRIES (default 6).
set -euo pipefail

POLL_SECONDS="${REBASE_MERGE_POLL_SECONDS:-10}"
DEPLOY_TIMEOUT="${REBASE_MERGE_DEPLOY_TIMEOUT:-600}"
PR_TRIES="${REBASE_MERGE_PR_TRIES:-6}"

# Without these, a stalled SSH connection to origin blocks a git network call for good (it once sat for 7 minutes).
# The options add to ~/.ssh/config. A command the user set themselves wins.
if [[ -z "${GIT_SSH_COMMAND:-}${GIT_SSH:-}" ]] && ! git config core.sshCommand >/dev/null; then
  export GIT_SSH_COMMAND="ssh -o ConnectTimeout=20 -o ServerAliveInterval=15 -o ServerAliveCountMax=4"
fi

kv() { printf '%s=%s\n' "$1" "$2"; }

die() {
  local code="$1"
  shift
  echo "rebase-merge: $*" >&2
  exit "$code"
}

primary_checkout() {
  git worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}'
}

# Prints origin's default branch, or main when origin/HEAD is not set.
default_base() {
  local head
  head="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)" || head=""
  if [[ "$head" == origin/?* ]]; then
    echo "${head#origin/}"
  else
    echo main
  fi
}

# Splits the arguments of prepare, land and cleanup into $base (from --base, else default_base) and $arg (the one
# optional positional argument), then prints base=<branch>.
parse_args() {
  base=""
  arg=""
  local positional=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --base)
        [[ -n "${2:-}" && "$2" != -* ]] || die 1 "--base needs a branch name"
        base="$2"
        shift 2
        ;;
      -*) die 1 "unknown option $1" ;;
      *)
        ((positional == 0)) || die 1 "unexpected argument $1"
        arg="$1"
        positional=1
        shift
        ;;
    esac
  done
  base="${base:-$(default_base)}"
  kv base "$base"
}

# Fails unless origin has the base branch. Call it after fetching.
require_base() {
  git -C "$1" rev-parse -q --verify "refs/remotes/origin/$base" >/dev/null || die 2 "origin has no branch $base"
}

worktree_for() {
  git worktree list --porcelain |
    awk -v ref="branch refs/heads/$1" '/^worktree /{path = substr($0, 10)} $0 == ref {print path; exit}'
}

# Resolves the branch argument (default: the current branch) and its worktree into $branch and $wt.
resolve_branch_worktree() {
  branch="${1:-$(git branch --show-current)}"
  [[ -n "$branch" ]] || die 2 "no branch given and HEAD is detached"
  [[ "$branch" != "$base" ]] || die 2 "refusing to land $base onto itself; name the feature branch"
  wt="$(worktree_for "$branch")"
  [[ -n "$wt" ]] || die 2 "no worktree has $branch checked out; create one with gwf"
  [[ "$wt" != "$(primary_checkout)" ]] || die 2 "$branch is checked out in the primary checkout; move it to a worktree"
}

# Go rewrites go.work.sum on its own whenever a build or test downloads a module, so a change to it is never work
# to keep. Restores it in checkout $1 and reports the path.
discard_go_work_sum() {
  if ! git -C "$1" diff --quiet HEAD -- go.work.sum 2>/dev/null; then
    git -C "$1" checkout -q HEAD -- go.work.sum
    kv discarded "$1/go.work.sum"
  fi
}

require_clean() {
  local dirty
  discard_go_work_sum "$1"
  dirty="$(git -C "$1" status --porcelain)"
  [[ -z "$dirty" ]] || die 2 "uncommitted changes in $1, commit them first:"$'\n'"$dirty"
}

vercel_apps_at() {
  git ls-tree -r --name-only "$1" | awk '/(^|\/)vercel\.json$/ {sub(/\/?vercel\.json$/, ""); print}'
}

cmd_prepare() {
  parse_args "$@"
  resolve_branch_worktree "$arg"
  require_clean "$wt"
  git -C "$wt" fetch -q origin
  require_base "$wt"

  local before after rebase_out conflicts
  before="$(git -C "$wt" rev-parse HEAD)"
  if ! rebase_out="$(git -C "$wt" rebase "origin/$base" 2>&1)"; then
    conflicts="$(git -C "$wt" diff --name-only --diff-filter=U)"
    git -C "$wt" rebase --abort
    if [[ -z "$conflicts" ]]; then
      die 1 "rebase failed without conflicts, aborted:"$'\n'"$rebase_out"
    fi
    while IFS= read -r f; do kv conflict "$f"; done <<<"$conflicts"
    die 3 "rebase onto origin/$base conflicts; aborted, the branch is unchanged"
  fi
  after="$(git -C "$wt" rev-parse HEAD)"

  local commits
  commits="$(git -C "$wt" rev-list --count "origin/$base..HEAD")"
  [[ "$commits" -gt 0 ]] || die 2 "$branch has no commits on top of origin/$base, nothing to land"

  git -C "$wt" push -q --force-with-lease -u origin "$branch" || die 5 "pushing $branch was rejected"
  [[ "$(git -C "$wt" rev-parse "$branch")" == "$(git -C "$wt" rev-parse "refs/remotes/origin/$branch")" ]] ||
    die 6 "origin/$branch does not match the local branch after the push"

  kv branch "$branch"
  kv worktree "$wt"
  kv head "$after"
  kv commits "$commits"
  kv rewritten "$([[ "$before" == "$after" ]] && echo no || echo yes)"
}

pr_state() {
  local out i
  command -v gh >/dev/null || { echo "unknown gh-not-on-path"; return; }
  for ((i = 1; i <= PR_TRIES; i++)); do
    if ! out="$(gh pr view "$1" --json state,url -q '.state + " " + .url' 2>&1)"; then
      if [[ "$out" == *"no pull requests found"* ]]; then
        echo none
      else
        echo "unknown $out"
      fi
      return
    fi
    [[ "$out" != MERGED* ]] || break
    ((i == PR_TRIES)) || sleep "$POLL_SECONDS"
  done
  echo "$out"
}

cmd_land() {
  parse_args "$@"
  resolve_branch_worktree "$arg"
  require_clean "$wt"
  git -C "$wt" fetch -q origin
  require_base "$wt"

  local tip remote_tip old_main push_out
  tip="$(git -C "$wt" rev-parse "$branch")"
  remote_tip="$(git -C "$wt" rev-parse -q --verify "refs/remotes/origin/$branch" || true)"
  [[ "$remote_tip" == "$tip" ]] || die 2 "origin/$branch is not the local tip; run prepare first"
  git -C "$wt" merge-base --is-ancestor "origin/$base" "$tip" ||
    die 4 "origin/$base moved since prepare; rerun prepare"

  old_main="$(git -C "$wt" rev-parse "origin/$base")"
  if ! push_out="$(git -C "$wt" push origin "$tip:refs/heads/$base" 2>&1)"; then
    # "cannot lock ref" is how GitHub answers when another push to the base lands while this one holds the ref.
    if [[ "$push_out" == *non-fast-forward* || "$push_out" == *"fetch first"* || "$push_out" == *"cannot lock ref"* ]]; then
      die 4 "origin/$base moved during the push; rerun prepare"
    fi
    die 5 "push to $base rejected:"$'\n'"$push_out"
  fi

  git -C "$wt" fetch -q origin
  [[ "$(git -C "$wt" rev-parse "origin/$base")" == "$tip" ]] || die 6 "origin/$base is not $tip after the push"

  local pr
  pr="$(pr_state "$branch")"
  kv old_main "$old_main"
  kv main "$tip"
  kv pr_state "${pr%% *}"
  [[ "$pr" != *" "* ]] || kv pr_detail "${pr#* }"
  kv vercel_apps "$(vercel_apps_at "$tip" | paste -sd ' ' -)"
}

# Polls the production deployment of one app for a commit until it reaches a final state. Prints the state and URL.
deploy_state() {
  local project="$1" sha="$2" deadline json url state err
  deadline=$((SECONDS + DEPLOY_TIMEOUT))
  err="$(mktemp)"
  while :; do
    if json="$(vercel ls "$project" --prod -m "githubCommitSha=$sha" --format json 2>"$err")"; then
      url="$(jq -r '.deployments[0].url // empty' <<<"$json")"
      state="$(jq -r '.deployments[0].state // empty' <<<"$json")"
      case "$state" in
        READY | ERROR | CANCELED)
          rm -f "$err"
          echo "$state $url"
          return
          ;;
      esac
    fi
    if ((SECONDS >= deadline)); then
      [[ ! -s "$err" ]] || cat "$err" >&2
      rm -f "$err"
      echo "${state:+TIMEOUT_}${state:-NOT_FOUND} ${url:-}"
      return
    fi
    sleep "$POLL_SECONDS"
  done
}

cmd_deploy() {
  git fetch -q origin
  local sha apps app result state url failed=0
  sha="$(git rev-parse "${1:-origin/$(default_base)}")"
  apps="$(vercel_apps_at "$sha")"
  kv sha "$sha"
  kv vercel_apps "$(paste -sd ' ' - <<<"$apps")"
  [[ -n "$apps" ]] || return 0
  command -v vercel >/dev/null || die 2 "vercel is not on PATH; ask the user instead of installing it"

  while IFS= read -r app; do
    result="$(deploy_state "$(basename "$app")" "$sha")"
    state="${result%% *}"
    url="${result#* }"
    case "$state" in
      READY) kv "deploy.$app" "READY https://$url" ;;
      CANCELED) kv "deploy.$app" "SKIPPED (ignored build step) https://$url" ;;
      *)
        kv "deploy.$app" "$state${url:+ https://$url}"
        [[ "$state" != ERROR ]] || vercel inspect --logs "$url" >&2 || echo "rebase-merge: vercel inspect --logs failed" >&2
        failed=1
        ;;
    esac
  done <<<"$apps"
  ((failed == 0)) || die 7 "a production deploy failed or did not finish in ${DEPLOY_TIMEOUT}s"
}

# Prints in_use=<pid> cwd=<dir> command=<command> for each process that a worktree removal message names, so the agent
# can tell its own dev servers and test runners from the user's processes without looking them up.
report_in_use() {
  local pid cwd command
  for pid in $(grep -oE '\(pid [0-9]+\)' <<<"$1" | grep -oE '[0-9]+'); do
    command="$(ps -o command= -p "$pid" 2>/dev/null)" || continue
    cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')" || cwd=""
    kv in_use "$pid cwd=${cwd:-unknown} command=$command"
  done
}

cmd_cleanup() {
  parse_args "$@"
  branch="$arg"
  [[ -n "$branch" ]] || die 1 "usage: cleanup <branch> [--base BRANCH]"
  [[ "$branch" != "$base" ]] || die 2 "refusing to delete $base"
  local primary tip wt rm_out pnpm_out remote_rc=0
  primary="$(primary_checkout)"
  cd "$primary"
  git fetch -q origin || die 1 "git fetch origin failed"
  require_base .

  # Fall back to origin's copy, so a cleanup that stopped after deleting the local branch can run again.
  tip="$(git rev-parse -q --verify "refs/heads/$branch" || git rev-parse -q --verify "refs/remotes/origin/$branch")" ||
    die 2 "no branch $branch locally or on origin"
  git merge-base --is-ancestor "$tip" "origin/$base" || die 6 "$branch is not on origin/$base; land it first"

  wt="$(worktree_for "$branch")"
  if [[ -n "$wt" ]]; then
    [[ "$wt" != "$primary" ]] || die 2 "$branch is checked out in the primary checkout"
    discard_go_work_sum "$wt"
    if command -v pnpm >/dev/null && ! pnpm_out="$( (cd "$wt" && pnpm exec nx daemon --stop) 2>&1)"; then
      echo "rebase-merge: stopping the Nx daemon in $wt failed, continuing:"$'\n'"$pnpm_out" >&2
    fi
    if command -v gwf >/dev/null; then
      rm_out="$(gwf rm -y -D "$branch" 2>&1)" || { report_in_use "$rm_out"; die 8 "gwf rm failed:"$'\n'"$rm_out"; }
    else
      rm_out="$(git worktree remove "$wt" 2>&1 && git branch -d "$branch" 2>&1 && git worktree prune 2>&1)" ||
        die 8 "removing the worktree failed:"$'\n'"$rm_out"
    fi
    [[ ! -d "$wt" ]] || { report_in_use "$rm_out"; die 8 "the worktree $wt is still there:"$'\n'"$rm_out"; }
    kv worktree_removed "$wt"
  fi
  if git show-ref -q --verify "refs/heads/$branch"; then
    git branch -d "$branch" >/dev/null || die 8 "git branch -d $branch refused"
  fi
  kv branch_deleted "$branch"

  # Exit code 2 alone means origin has no such branch. Anything else is a network or auth error, not a deletion.
  git ls-remote -q --exit-code --heads origin "$branch" >/dev/null || remote_rc=$?
  case "$remote_rc" in
    0) git push -q origin --delete "$branch" || die 5 "deleting origin/$branch was rejected" ;;
    2) ;;
    *) die 1 "checking origin/$branch failed (git ls-remote exited $remote_rc); the remote branch may still exist" ;;
  esac
  kv remote_branch_deleted "$branch"

  [[ "$(git branch --show-current)" != "$base" ]] || discard_go_work_sum "$primary"
  if [[ "$(git branch --show-current)" != "$base" ]]; then
    kv pulled "skipped (primary checkout is on $(git branch --show-current || echo 'a detached HEAD'))"
  elif [[ -n "$(git status --porcelain)" ]]; then
    kv pulled "skipped (primary checkout has uncommitted changes)"
  else
    git pull -q --ff-only || die 6 "git pull --ff-only failed in the primary checkout"
    kv pulled yes
  fi
  kv main "$(git rev-parse "origin/$base")"
}

case "${1:-}" in
  prepare | land | deploy | cleanup)
    cmd="$1"
    shift
    "cmd_$cmd" "$@"
    ;;
  *) die 1 "usage: rebase-merge.sh prepare|land|deploy|cleanup [branch|sha] [--base BRANCH]" ;;
esac
