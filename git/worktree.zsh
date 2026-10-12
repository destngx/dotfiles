# Git worktree helpers powered by fzf.
#
#   gwf [switch|s] [query]        switch to a worktree (default; `gwf <query>` also works)
#   gwf list|ls [-s|--size]       list worktrees (* marks the current one); --size adds disk usage
#                                 and the age of the last commit
#   gwf create|c [branch] [base]  create a worktree and cd into it; with no branch, pick one with fzf
#                                 (local, remote, or type a new name). New branches start from <base>,
#                                 defaulting to origin's default branch (fetched first), then HEAD.
#   gwf remove|rm [query]         remove worktree(s) (multi-select with tab) after confirmation,
#                                 optionally deleting their branches
#   gwf remove|rm -y [-D] <worktree>...
#                                 remove the named worktrees (path, branch, or directory name) without
#                                 prompts; dirty or in-use ones are skipped, -D deletes merged branches
#   gwf gc [-y] [-D] [days]       offer stale worktrees for removal: branch merged into origin's default
#                                 branch, upstream gone, or clean and idle for [days] (default 14).
#                                 Without a terminal it only lists them; -y removes them without prompts
#   gwf trust                     review and trust this repo's .gwf/setup
#
# New worktrees live in <main-worktree>-worktrees/<dir>, or $GWT_ROOT/<repo>/<dir> when set, where
# <dir> is the branch without its type prefix ("feat/app-topic" -> "app-topic").
# After creating a worktree, an executable .gwf/setup runs with the worktree as cwd (install deps,
# write local env), so agents and humans get a ready-to-use checkout. It is taken from the new worktree
# when the repo commits one, else from the main worktree, so a local, untracked script in the main
# checkout serves every worktree. It only runs once its exact content is trusted for that repo (like
# `direnv allow`).
# Worktrees that some process is using (its cwd is inside) are never removed without asking.

_gwf_tty() { [[ -t 0 ]] }

_gwf_require() {
  command git rev-parse --git-dir >/dev/null 2>&1 || { print -u2 "gwf: not inside a git repository"; return 1; }
  ! _gwf_tty || (( $+commands[fzf] )) || { print -u2 "gwf: fzf is not installed"; return 1; }
}

# One "path<TAB>branch<TAB>sha" line per worktree; the main worktree comes first.
_gwf_rows() {
  command git worktree list --porcelain | awk '
    /^worktree / { wt = substr($0, 10); branch = ""; sha = "" }
    /^HEAD /     { sha = substr($2, 1, 7) }
    /^branch /   { branch = substr($2, 12) }
    /^detached$/ { branch = "(detached)" }
    /^bare$/     { branch = "(bare)" }
    /^$/         { if (wt != "") print wt "\t" branch "\t" sha; wt = "" }
    END          { if (wt != "") print wt "\t" branch "\t" sha }
  '
}

_gwf_main() { _gwf_rows | head -n1 | cut -f1 }

_gwf_default_base() {
  command git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || print HEAD
}

# Refresh origin so new branches and staleness checks see its current state; offline is not an error.
_gwf_fetch() {
  command git remote get-url origin >/dev/null 2>&1 || return 0
  GIT_TERMINAL_PROMPT=0 command git fetch --quiet --prune origin 2>/dev/null ||
    print -u2 "gwf: could not fetch origin, using local refs"
}

# Rows as "path<TAB>colored display line", so fzf can show field 2 and return field 1.
_gwf_display() {
  local top=$(command git rev-parse --show-toplevel 2>/dev/null)
  _gwf_rows | awk -F'\t' -v top="$top" -v home="$HOME" '
    {
      shown = $1
      if (index(shown, home) == 1) shown = "~" substr(shown, length(home) + 1)
      mark = ($1 == top) ? "\033[1;35m*\033[0m" : " "
      printf "%s\t%s \033[32m%-32s\033[0m \033[33m%s\033[0m  \033[2m%s\033[0m\n", $1, mark, $2, $3, shown
    }'
}

_gwf_pick() {
  _gwf_display | fzf --ansi --reverse --height=50% --delimiter='\t' --with-nth=2 --exit-0 \
    --preview='git -C {1} -c color.status=always status -sb; echo; git -C {1} log --oneline --graph --color=always -30' \
    --preview-window='right,55%' "$@" | cut -f1
}

# Worktree paths named by each argument (path, branch, or directory name); fails on any unknown one.
_gwf_resolve() {
  local arg wt
  for arg; do
    wt=$(_gwf_rows | awk -F'\t' -v a="$arg" -v p="${arg:A}" '
      { n = split($1, parts, "/") }
      $1 == p || $2 == a || parts[n] == a { print $1; exit }')
    [[ -n $wt ]] || { print -u2 "gwf: no worktree matches '$arg'"; return 1; }
    print -r -- "$wt"
  done
}

# "pid<TAB>command<TAB>cwd" for every process except this shell. Runs from / so the lookup itself
# does not count as using a worktree.
_gwf_cwds() {
  (
    cd / || return
    if (( $+commands[lsof] )); then
      lsof -w -d cwd -F pcn 2>/dev/null | awk '
        /^p/ { pid = substr($0, 2) }
        /^c/ { cmd = substr($0, 2) }
        /^n/ { print pid "\t" cmd "\t" substr($0, 2) }'
    elif [[ -d /proc ]]; then
      local p cwd
      for p in /proc/<->(N); do
        cwd=$(readlink -- $p/cwd 2>/dev/null) || continue
        print -r -- "${p:t}"$'\t'"$(<$p/comm)"$'\t'"$cwd"
      done 2>/dev/null
    fi
  ) | awk -F'\t' -v self=$$ '$1 != self'
}

# Indented "command (pid N)" lines for processes in $1 (_gwf_cwds output) whose cwd is inside $2.
_gwf_users() {
  print -r -- "$1" | awk -F'\t' -v wt="${2:A}" '
    $3 == wt || index($3, wt "/") == 1 { print "    " $2 " (pid " $1 ")" }'
}

_gwf_list() {
  if [[ $1 != (-s|--size) ]]; then
    _gwf_display | cut -f2
    return
  fi
  # du counts APFS clones (pnpm's default import on macOS) at full size, so shared node_modules
  # look bigger than they really are.
  local wt line size age
  _gwf_display | while IFS=$'\t' read -r wt line; do
    size=$(du -sh -- "$wt" 2>/dev/null | cut -f1)
    age=$(command git -C "$wt" log -1 --format=%cr 2>/dev/null)
    printf '%s \033[36m%6s\033[0m  \033[2m%s\033[0m\n' "$line" "$size" "$age"
  done
}

_gwf_switch() {
  _gwf_tty || { print -u2 "gwf: switch needs a terminal; use 'gwf list'"; return 1; }
  local dest
  dest=$(_gwf_pick --prompt='worktree> ' --query="$*" --select-1)
  [[ -n $dest ]] && cd -- "$dest"
}

_gwf_trust_file() { print -r -- "${XDG_DATA_HOME:-$HOME/.local/share}/gwf/trusted" }

# Trust entries are "<blob hash of .gwf/setup> <main worktree path>".
_gwf_trusted() {
  local setup=$1 main=$2 file=$(_gwf_trust_file) hash
  hash=$(command git hash-object --no-filters -- "$setup") || return
  [[ -f $file ]] && grep -qxF -- "$hash $main" "$file"
}

# Show the setup script and record its content as trusted for this repo, replacing older entries.
_gwf_trust_setup() {
  local setup=$1 main=$2 file=$(_gwf_trust_file) hash
  _gwf_tty || { print -u2 "gwf: trusting .gwf/setup needs a terminal"; return 1; }
  print "----- ${setup/#$HOME/~} -----"
  command cat -- "$setup"
  print "-----"
  read -q "?Trust this .gwf/setup for ${main/#$HOME/~}? It runs after every 'gwf create'. [y/N] " ||
    { print; return 1; }
  print
  hash=$(command git hash-object --no-filters -- "$setup") || return
  mkdir -p -- "${file:h}" || return
  {
    [[ -f $file ]] && awk -v m="$main" 'substr($0, index($0, " ") + 1) != m' "$file"
    print -r -- "$hash $main"
  } >"$file.tmp" && mv -- "$file.tmp" "$file"
}

# The .gwf/setup for worktree $1: its own (committed) one, else the main worktree's.
_gwf_setup_path() {
  local wt=$1 main=$2
  if [[ -e $wt/.gwf/setup ]]; then
    print -r -- "$wt/.gwf/setup"
  elif [[ -e $main/.gwf/setup ]]; then
    print -r -- "$main/.gwf/setup"
  else
    return 1
  fi
}

_gwf_trust() {
  local top=$(command git rev-parse --show-toplevel) main=$(_gwf_main) setup
  setup=$(_gwf_setup_path "$top" "$main") || { print -u2 "gwf: no .gwf/setup in $top or $main"; return 1; }
  _gwf_trusted "$setup" "$main" && { print "gwf: ${setup/#$HOME/~} is already trusted"; return; }
  _gwf_trust_setup "$setup" "$main"
}

# Run .gwf/setup (cwd = the new worktree) if its content is trusted, offering to trust it when a
# terminal is available.
_gwf_run_setup() {
  local main=$1 setup
  setup=$(_gwf_setup_path "$PWD" "$main") && [[ -x $setup ]] || return 0
  if ! _gwf_trusted "$setup" "$main"; then
    if ! _gwf_tty; then
      print -u2 "gwf: skipped untrusted .gwf/setup; a human must review it with 'gwf trust'"
      return
    fi
    _gwf_trust_setup "$setup" "$main" || { print "gwf: skipped .gwf/setup"; return; }
  fi
  print "gwf: running ${setup/#$HOME/~}"
  "$setup" || print -u2 "gwf: .gwf/setup failed (exit $?); the worktree is still usable"
}

_gwf_create() {
  local branch=$1 base=$2 sel main root dest existing

  # Picking or creating a branch needs origin's current branches; reusing a local one does not.
  if [[ -z $branch ]] || ! command git show-ref --verify --quiet "refs/heads/$branch"; then
    _gwf_fetch
  fi

  if [[ -z $branch ]]; then
    _gwf_tty || { print -u2 "gwf: no terminal to pick a branch; pass one: gwf create <branch> [base]"; return 1; }
    sel=$(command git for-each-ref --sort=-committerdate --format='%(refname)' refs/heads refs/remotes |
      awk '!/\/HEAD$/ { sub(/^refs\/(heads|remotes)\//, ""); print }' |
      fzf --reverse --height=50% --prompt='branch> ' \
        --header='enter: select (or create from query if no match) | alt-enter: create from query' \
        --bind='enter:accept-or-print-query,alt-enter:print-query' \
        --preview='git log --oneline --graph --color=always -30 {}' --preview-window='right,55%')
    [[ -n $sel ]] || return 1
    branch=$sel
  fi

  # A picked remote ref (origin/foo) becomes a local tracking branch named foo.
  local remote_ref=""
  if ! command git show-ref --verify --quiet "refs/heads/$branch" &&
     command git show-ref --verify --quiet "refs/remotes/$branch"; then
    remote_ref=$branch
    branch=${branch#*/}
  fi

  # Already checked out somewhere? Just go there.
  existing=$(_gwf_rows | awk -F'\t' -v b="$branch" '$2 == b { print $1; exit }')
  if [[ -n $existing ]]; then
    print "gwf: '$branch' is already checked out at $existing"
    cd -- "$existing"
    return
  fi

  main=$(_gwf_main)
  if [[ -n $GWT_ROOT ]]; then
    root=$GWT_ROOT/${${main:t}%.git}
  else
    root=${main%.git}-worktrees
  fi
  dest=${branch#*/}
  dest=$root/${dest//\//-}
  [[ -e $dest ]] && { print -u2 "gwf: $dest already exists"; return 1; }

  if command git show-ref --verify --quiet "refs/heads/$branch"; then
    command git worktree add -- "$dest" "$branch" || return
  elif [[ -n $remote_ref ]]; then
    command git worktree add --track -b "$branch" -- "$dest" "$remote_ref" || return
  else
    [[ -n $base ]] || base=$(_gwf_default_base)
    command git worktree add --no-track -b "$branch" -- "$dest" "$base" || return
  fi
  cd -- "$dest"
  _gwf_run_setup "$main"
}

_gwf_remove() {
  local -a flags targets
  while [[ $1 == -* ]]; do
    case $1 in
      -y|--yes)           flags+=(-y) ;;
      -D|--delete-branch) flags+=(-D) ;;
      *) print -u2 "gwf: unknown option $1"; return 1 ;;
    esac
    shift
  done

  if (( ${flags[(Ie)-y]} )); then
    (( $# )) || { print -u2 "gwf: name the worktrees to remove"; return 1; }
    targets=(${(f)"$(_gwf_resolve "$@")"}) || return
  else
    _gwf_tty || { print -u2 "gwf: no terminal; use: gwf remove --yes [-D] <worktree>..."; return 1; }
    targets=(${(f)"$(_gwf_pick --multi --prompt='remove> ' --query="$*" \
      --header='tab: mark multiple | main worktree cannot be removed')"})
  fi
  _gwf_remove_paths $flags -- $targets
}

# Clean worktrees (no uncommitted changes) that are done or abandoned, as "path<TAB>reason": upstream
# gone (catches squash merges), merged into origin's default branch with commits of their own, or no
# commit and not created within $1 days. A fresh branch with no commits yet also counts as "merged",
# so it only qualifies once it goes idle.
_gwf_stale() {
  local days=${1:-14} main=$(_gwf_main) base=$(_gwf_default_base) now=$(date +%s) wt branch sha ts
  local -a merged gone created
  merged=(${(f)"$(command git for-each-ref --merged="$base" --format='%(refname:short)' refs/heads)"})
  gone=(${(f)"$(command git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads |
    awk '$2 == "[gone]" { print $1 }')"})
  zmodload -F zsh/stat b:zstat

  _gwf_rows | while IFS=$'\t' read -r wt branch sha; do
    [[ $wt == $main || ! -d $wt ]] && continue
    [[ -n $(command git -C "$wt" status --porcelain 2>/dev/null) ]] && continue
    if (( ${gone[(Ie)$branch]} )); then
      print -r -- "$wt"$'\t'"upstream gone"
    elif (( ${merged[(Ie)$branch]} )) &&
         (( $(command git reflog show --format=%H "refs/heads/$branch" -- 2>/dev/null | wc -l) > 1 )); then
      # merged and the branch moved after creation, i.e. it had real work that landed
      print -r -- "$wt"$'\t'"merged"
    else
      # Last sign of life: the newest commit, or the worktree's creation (git writes commondir once,
      # in add), so a fresh worktree on an old base is not idle.
      ts=$(command git -C "$wt" log -1 --format=%ct 2>/dev/null)
      created=()
      zstat -A created +mtime -- "$(command git -C "$wt" rev-parse --absolute-git-dir)/commondir" 2>/dev/null
      (( ${created[1]:-0} > ${ts:-0} )) && ts=$created[1]
      [[ -n $ts ]] && (( now - ts > days * 86400 )) && print -r -- "$wt"$'\t'"idle $(( (now - ts) / 86400 ))d"
    fi
  done
}

_gwf_gc() {
  local days yes=0 arg cwds wt reason users
  local -a flags candidates targets
  for arg; do
    case $arg in
      -y|--yes)           yes=1; flags+=(-y) ;;
      -D|--delete-branch) flags+=(-D) ;;
      <->)                days=$arg ;;
      *) print -u2 "gwf: usage: gwf gc [-y] [-D] [days]"; return 1 ;;
    esac
  done

  _gwf_fetch
  cwds=$(_gwf_cwds)
  _gwf_stale $days | while IFS=$'\t' read -r wt reason; do
    users=$(_gwf_users "$cwds" "$wt")
    if [[ -n $users ]]; then
      print "gwf: keeping ${wt/#$HOME/~} ($reason), in use by:\n$users"
    else
      candidates+=("$wt"$'\t'"$reason")
    fi
  done
  (( $#candidates )) || { print "gwf: no stale worktrees"; return }

  if (( ! yes )) && ! _gwf_tty; then
    print "Stale worktrees (run 'gwf gc --yes' to remove):"
    for wt in $candidates; do print "  ${${wt%%$'\t'*}/#$HOME/~}  (${wt#*$'\t'})"; done
    return
  fi

  command git worktree prune
  if (( yes )); then
    targets=(${candidates%%$'\t'*})
  else
    # Show only stale worktrees with their reason, all preselected; tab deselects the ones to keep.
    targets=(${(f)"$(_gwf_display | awk -F'\t' 'NR == FNR { why[$1] = $2; next }
        $1 in why { print $0 "  \033[36m" why[$1] "\033[0m" }' <(print -rl -- $candidates) - |
      fzf --ansi --reverse --height=50% --delimiter='\t' --with-nth=2 --multi --prompt='gc> ' \
        --header='stale worktrees, all selected | tab: keep one | enter: continue' --bind='load:select-all' \
        --preview='git -C {1} -c color.status=always status -sb; echo; git -C {1} log --oneline --graph --color=always -30' \
        --preview-window='right,55%' | cut -f1)"})
  fi
  _gwf_remove_paths $flags -- $targets
}

# Remove the given worktree paths. Interactively: confirm, then offer to remove in-use or dirty
# worktrees anyway and to delete their branches. With -y: no prompts, in-use and dirty worktrees are
# skipped, and -D deletes branches that are fully merged.
_gwf_remove_paths() {
  local yes=0 delete_branch=0 failed=0 main=$(_gwf_main) wt branch cwds users
  while [[ $1 != -- ]]; do
    case $1 in -y) yes=1 ;; -D) delete_branch=1 ;; esac
    shift
  done
  shift
  local -a targets=("$@")
  if (( ${targets[(Ie)$main]} )); then
    print -u2 "gwf: skipping main worktree $main"
    targets=(${targets:#$main})
  fi
  (( $#targets )) || return 1
  cwds=$(_gwf_cwds)

  if (( ! yes )); then
    print "Worktrees to remove:"
    for wt in $targets; do
      branch=$(command git -C "$wt" branch --show-current 2>/dev/null)
      print "  ${branch:-(detached)}  ${wt/#$HOME/~}"
      users=$(_gwf_users "$cwds" "$wt")
      [[ -n $users ]] && print "    in use by:\n$users"
    done
    read -q "?Remove ${#targets} worktree(s)? [y/N] " || { print; return 1; }
    print
  fi

  for wt in $targets; do
    branch=$(command git -C "$wt" branch --show-current 2>/dev/null)
    users=$(_gwf_users "$cwds" "$wt")
    if [[ -n $users ]]; then
      if (( yes )); then
        print -u2 "gwf: skipping $wt, in use by:\n$users"
        failed=1
        continue
      fi
      read -q "?gwf: $wt is in use. Remove anyway? [y/N] " || { print; continue; }
      print
    fi
    [[ $PWD == $wt || $PWD == $wt/* ]] && cd -- "$main"

    if ! command git worktree remove -- "$wt" 2>/dev/null; then
      if (( yes )); then
        print -u2 "gwf: skipping $wt, it has uncommitted changes"
        failed=1
        continue
      fi
      command git -C "$wt" status -s
      read -q "?gwf: $wt has changes. Force remove (discards them)? [y/N] " || { print; continue; }
      print
      command git worktree remove --force -- "$wt" || continue
    fi
    print "removed $wt"
    [[ -n $branch ]] || continue

    if (( yes )); then
      (( delete_branch )) && { command git branch -d -- "$branch" || failed=1 }
    elif read -q "?Delete branch '$branch'? [y/N] "; then
      print
      command git branch -d -- "$branch" ||
        { read -q "?'$branch' is not fully merged. Force delete? [y/N] " && command git branch -D -- "$branch"; print; }
    else
      print
    fi
  done
  command git worktree prune
  return $failed
}

gwf() {
  local cmd=${1:-switch}
  (( $# )) && shift
  case $cmd in
    -h|--help|help)
      print "usage: gwf [switch|s] [query]
       gwf list|ls [-s|--size]
       gwf create|c [branch] [base]
       gwf remove|rm [query]
       gwf remove|rm -y [-D] <worktree>...
       gwf gc [-y] [-D] [days]
       gwf trust"
      return ;;
  esac
  _gwf_require || return
  case $cmd in
    switch|s)  _gwf_switch "$@" ;;
    list|ls)   _gwf_list "$@" ;;
    create|c)  _gwf_create "$@" ;;
    remove|rm) _gwf_remove "$@" ;;
    gc)        _gwf_gc "$@" ;;
    trust)     _gwf_trust ;;
    *)         _gwf_switch "$cmd" "$@" ;;
  esac
}

if (( $+functions[compdef] )); then
  # Offer each worktree's branch (or directory name when detached), described by its path.
  _gwf_complete_worktrees() {
    local wt branch sha
    local -a names displays
    while IFS=$'\t' read -r wt branch sha; do
      [[ $branch == \(*\) ]] && branch=${wt:t}
      names+=("$branch")
      displays+=("$branch  -- ${wt/#$HOME/~}")
    done < <(_gwf_rows 2>/dev/null)
    (( $#names )) && compadd -J worktrees -X '%Bworktree%b' -l -d displays -a names
  }

  _gwf() {
    local -a cmds=(
      'switch:switch to a worktree'
      'list:list worktrees'
      'create:create a worktree and cd into it'
      'remove:remove worktrees'
      'gc:remove stale worktrees'
      'trust:review and trust .gwf/setup'
    )
    if (( CURRENT == 2 )); then
      _describe -t commands 'gwf command' cmds
      _gwf_complete_worktrees
    elif [[ $words[2] == (remove|rm) ]]; then
      compadd -- -y -D
      _gwf_complete_worktrees
    elif [[ $words[2] == gc ]]; then
      compadd -- -y -D
    elif (( CURRENT == 3 )) && [[ $words[2] == (switch|s) ]]; then
      _gwf_complete_worktrees
    elif [[ $words[2] == (create|c) ]]; then
      local -a branches=(${(f)"$(command git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)"})
      compadd -a branches
    fi
  }
  compdef _gwf gwf
fi
