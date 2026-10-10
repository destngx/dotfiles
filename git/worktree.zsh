# Git worktree helpers powered by fzf.
#
#   gwf [switch|s] [query]        switch to a worktree (default; `gwf <query>` also works)
#   gwf list|ls                   list worktrees (* marks the current one)
#   gwf create|c [branch] [base]  create a worktree and cd into it; with no branch, pick one with fzf
#                                 (local, remote, or type a new name). New branches start from <base>,
#                                 defaulting to origin's default branch, then HEAD.
#   gwf remove|rm [query]         remove worktree(s) (multi-select with tab) after confirmation,
#                                 optionally deleting their branches
#
# New worktrees live in <main-worktree>.worktrees/<branch>, or $GWT_ROOT/<repo>/<branch> when set.

_gwf_require() {
  command git rev-parse --git-dir >/dev/null 2>&1 || { print -u2 "gwf: not inside a git repository"; return 1; }
  (( $+commands[fzf] )) || { print -u2 "gwf: fzf is not installed"; return 1; }
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

_gwf_list() {
  _gwf_display | cut -f2
}

_gwf_switch() {
  local dest
  dest=$(_gwf_pick --prompt='worktree> ' --query="$*" --select-1)
  [[ -n $dest ]] && cd -- "$dest"
}

_gwf_create() {
  local branch=$1 base=$2 sel main root dest existing

  if [[ -z $branch ]]; then
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
    root=${main%.git}.worktrees
  fi
  dest=$root/${branch//\//-}
  [[ -e $dest ]] && { print -u2 "gwf: $dest already exists"; return 1; }

  if command git show-ref --verify --quiet "refs/heads/$branch"; then
    command git worktree add -- "$dest" "$branch" || return
  elif [[ -n $remote_ref ]]; then
    command git worktree add --track -b "$branch" -- "$dest" "$remote_ref" || return
  else
    if [[ -z $base ]]; then
      base=$(command git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || base=HEAD
    fi
    command git worktree add --no-track -b "$branch" -- "$dest" "$base" || return
  fi
  cd -- "$dest"
}

_gwf_remove() {
  local main=$(_gwf_main) wt branch
  local -a targets
  targets=(${(f)"$(_gwf_pick --multi --prompt='remove> ' --query="$*" \
    --header='tab: mark multiple | main worktree cannot be removed')"})
  if (( ${targets[(Ie)$main]} )); then
    print -u2 "gwf: skipping main worktree $main"
    targets=(${targets:#$main})
  fi
  (( $#targets )) || return 1

  print "Worktrees to remove:"
  for wt in $targets; do
    branch=$(command git -C "$wt" branch --show-current 2>/dev/null)
    print "  ${branch:-(detached)}  ${wt/#$HOME/~}"
  done
  read -q "?Remove ${#targets} worktree(s)? [y/N] " || { print; return 1; }
  print

  for wt in $targets; do
    branch=$(command git -C "$wt" branch --show-current 2>/dev/null)
    [[ $PWD == $wt || $PWD == $wt/* ]] && cd -- "$main"

    if ! command git worktree remove -- "$wt" 2>/dev/null; then
      command git -C "$wt" status -s
      read -q "?gwf: $wt has changes. Force remove (discards them)? [y/N] " || { print; continue; }
      print
      command git worktree remove --force -- "$wt" || continue
    fi
    print "removed $wt"

    if [[ -n $branch ]] && read -q "?Delete branch '$branch'? [y/N] "; then
      print
      command git branch -d -- "$branch" ||
        { read -q "?'$branch' is not fully merged. Force delete? [y/N] " && command git branch -D -- "$branch"; print; }
    else
      print
    fi
  done
  command git worktree prune
}

gwf() {
  local cmd=${1:-switch}
  (( $# )) && shift
  case $cmd in
    -h|--help|help)
      print "usage: gwf [switch|s] [query]\n       gwf list|ls\n       gwf create|c [branch] [base]\n       gwf remove|rm [query]"
      return ;;
  esac
  _gwf_require || return
  case $cmd in
    switch|s)  _gwf_switch "$@" ;;
    list|ls)   _gwf_list ;;
    create|c)  _gwf_create "$@" ;;
    remove|rm) _gwf_remove "$@" ;;
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
    )
    if (( CURRENT == 2 )); then
      _describe -t commands 'gwf command' cmds
      _gwf_complete_worktrees
    elif (( CURRENT == 3 )) && [[ $words[2] == (switch|s|remove|rm) ]]; then
      _gwf_complete_worktrees
    elif [[ $words[2] == (create|c) ]]; then
      local -a branches=(${(f)"$(command git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)"})
      compadd -a branches
    fi
  }
  compdef _gwf gwf
fi
