# Nx in the current workspace, with completion that fzf-tab turns into a fuzzy picker.
#
#   nx <args>    runs the workspace's pinned Nx (`pnpm exec nx`)
#
# Completion works for `nx`, `pnpm nx`, `pnpm exec nx` and `pnpx nx` (and the `pn`/`px` aliases):
#   nx <Tab>                          project:target pairs, then Nx commands
#   nx run <Tab>                      project:target, plus project:target:configuration
#   nx <target> <Tab>                 projects that have <target>
#   nx run-many|affected -t <Tab>     targets; -p/--projects/--exclude <Tab> projects, comma-separated
#   nx show project <Tab>             projects
#   pnpm <Tab>, pnpm run <Tab>        root package.json scripts
# Projects and targets come from the graph Nx caches in .nx/workspace-data/project-graph.json, read
# with jq. When the file is missing, Nx computes it once. A target added since Nx last ran shows up
# after the next Nx command.

nx() { command pnpm exec nx "$@" }

if (( $+functions[compdef] )); then
  zmodload -F zsh/stat b:zstat

  # Rows of the last graph read, and the "path:mtime" they came from.
  typeset -ga _nx_rows
  typeset -g _nx_rows_key

  # Nearest directory at or above $PWD holding nx.json.
  _nx_root() {
    local dir=$PWD
    until [[ -f $dir/nx.json ]]; do
      [[ $dir == / ]] && return 1
      dir=${dir:h}
    done
    print -r -- $dir
  }

  # Fill _nx_rows with "project<TAB>target<TAB>configs<TAB>description" lines, configs comma-joined.
  _nx_load() {
    local root graph mtime
    root=$(_nx_root) || return 1
    graph=$root/.nx/workspace-data/project-graph.json
    [[ -s $graph ]] || (cd $root && command pnpm exec nx show projects >/dev/null 2>&1)
    [[ -s $graph ]] || return 1
    mtime=$(zstat +mtime -- $graph) || return 1
    [[ $_nx_rows_key == $graph:$mtime ]] && return 0
    _nx_rows=(${(f)"$(command jq -r '
      .nodes | to_entries[] | .key as $p | .value.data.targets // {} | to_entries[] |
      [$p, .key, ((.value.configurations // {}) | keys | join(",")),
       (.value.options.command
        // (.value.options.commands | if type == "array"
              then map(if type == "string" then . else .command end) | join(" && ") else null end)
        // .value.executor // "")]
      | @tsv' $graph 2>/dev/null)"})
    (( $#_nx_rows )) || return 1
    _nx_rows_key=$graph:$mtime
  }

  _nx_complete_projects() {
    local -a projects=(${(uo)${_nx_rows%%$'\t'*}})
    compadd -J projects -X '%Bproject%b' "$@" -a projects
  }

  # Targets, each described by the projects that have it.
  _nx_complete_targets() {
    local row p t
    local -A owners
    for row in $_nx_rows; do
      p=${row%%$'\t'*}; t=${${row#*$'\t'}%%$'\t'*}
      owners[$t]+="${owners[$t]:+, }$p"
    done
    local -a targets=(${(ko)owners}) displays
    for t in $targets; do displays+=("$t  -- $owners[$t]"); done
    compadd -J targets -X '%Btarget%b' -l -d displays "$@" -a targets
  }

  # project:target pairs described by their command; with -c, configurations too.
  _nx_complete_project_targets() {
    local row p t configs desc c
    local -a names displays
    for row in $_nx_rows; do
      p=${row%%$'\t'*}; row=${row#*$'\t'}
      t=${row%%$'\t'*}; row=${row#*$'\t'}
      configs=${row%%$'\t'*}; desc=${row#*$'\t'}
      names+=("$p:$t"); displays+=("$p:$t  -- $desc")
      if [[ $1 == -c && -n $configs ]]; then
        for c in ${(s:,:)configs}; do
          names+=("$p:$t:$c"); displays+=("$p:$t:$c  -- configuration $c")
        done
      fi
    done
    compadd -J project-targets -X '%Bproject:target%b' -l -d displays -a names
  }

  # Whether some project has target $1.
  _nx_is_target() {
    setopt localoptions extendedglob
    # $'\t' is not expanded inside a subscript pattern, a variable is.
    local tab=$'\t'
    (( ${_nx_rows[(I)[^$tab]##$tab${(b)1}$tab*]} ))
  }

  # Projects that have target $1.
  _nx_complete_projects_with() {
    setopt localoptions extendedglob
    local tab=$'\t'
    local -a projects=(${(uo)${(M)_nx_rows:#[^$tab]##$tab${(b)1}$tab*}%%$tab*})
    compadd -J projects -X "%Bproject with $1%b" -a projects
  }

  _nx() {
    local -a cmds=(
      'run:run a project:target'
      'run-many:run targets for many projects'
      'affected:run targets for projects affected by a change'
      'show:show projects or one project'
      'graph:open the project graph'
      'reset:clear the cache and stop the daemon'
      'daemon:manage the Nx daemon'
      'generate:run a generator'
      'add:install a plugin'
      'sync:sync workspace files'
      'format\:write:format files'
      'format\:check:check formatting'
      'report:print versions for bug reports'
      'migrate:update Nx and run migrations'
      'release:version and publish projects'
      'watch:run a command on file changes'
    )
    local -a run_opts=(
      '--configuration:configuration to use'
      '--skip-nx-cache:ignore cached results'
      '--verbose:print stack traces'
      '--output-style:how task output is shown'
      '--exclude-task-dependencies:skip dependsOn tasks'
    )
    local -a many_opts=(
      '--targets:targets to run'
      '--projects:projects to run'
      '--exclude:projects to skip'
      '--parallel:max tasks at once'
      $run_opts
    )
    local -a affected_opts=('--base:base ref' '--head:head ref' '--files:changed files' $many_opts)

    _nx_load || { (( CURRENT == 2 )) && _describe -t commands 'nx command' cmds; return }

    local cur=$words[CURRENT] prev=$words[CURRENT-1]
    if (( CURRENT == 2 )); then
      _nx_complete_project_targets
      _describe -t commands 'nx command' cmds
      return
    fi

    # Values of --flag=value and space-separated -flag value.
    local flag=$prev
    if [[ $cur == --*=* ]]; then
      flag=${cur%%=*}
      compset -P '*='
    fi
    case $flag in
      -t|--target|--targets)
        compset -P '*,'
        _nx_complete_targets -S ''
        return ;;
      -p|--projects|--exclude)
        compset -P '*,'
        _nx_complete_projects -S ''
        return ;;
      --output-style)
        compadd -- dynamic static stream stream-without-prefixes tui
        return ;;
      -c|--configuration|--base|--head|--files|--parallel)
        return ;;
    esac

    case $words[2] in
      run)
        if (( CURRENT == 3 )); then _nx_complete_project_targets -c
        else _describe -t options 'option' run_opts; fi ;;
      run-many) _describe -t options 'option' many_opts ;;
      affected) _describe -t options 'option' affected_opts ;;
      show)
        if (( CURRENT == 3 )); then compadd -- projects project
        elif [[ $words[3] == project ]] && (( CURRENT == 4 )); then _nx_complete_projects
        else compadd -- --json --web; fi ;;
      graph) compadd -- --focus --file --affected --watch ;;
      daemon) compadd -- --start --stop ;;
      *:*) _describe -t options 'option' run_opts ;;
      *)
        # `nx <target> <project>`
        if (( CURRENT == 3 )) && _nx_is_target $words[2]; then
          _nx_complete_projects_with $words[2]
        else
          _describe -t options 'option' run_opts
        fi ;;
    esac
  }

  # Root package.json scripts, described by their command.
  _nx_complete_scripts() {
    local dir=$PWD row
    until [[ -f $dir/package.json ]]; do
      [[ $dir == / ]] && return 1
      dir=${dir:h}
    done
    local -a rows=(${(f)"$(command jq -r '.scripts // {} | to_entries[] | [.key, .value] | @tsv' $dir/package.json 2>/dev/null)"})
    local -a names=(${rows%%$'\t'*}) displays
    for row in $rows; do displays+=("${row%%$'\t'*}  -- ${row#*$'\t'}"); done
    (( $#names )) && compadd -J scripts -X '%Bscript%b' -l -d displays -a names
  }

  _nx_pnpm() {
    if (( CURRENT > 2 )) && [[ $words[2] == nx ]]; then
      shift words; (( CURRENT-- )); _nx
    elif (( CURRENT > 3 )) && [[ $words[2] == exec && $words[3] == nx ]]; then
      shift 2 words; (( CURRENT -= 2 )); _nx
    elif (( CURRENT == 2 )); then
      _nx_complete_scripts
      compadd -J commands -X '%Bcommand%b' -- nx exec run install add remove update dlx
    elif (( CURRENT == 3 )) && [[ $words[2] == run ]]; then
      _nx_complete_scripts
    elif (( CURRENT == 3 )) && [[ $words[2] == exec ]]; then
      compadd -- nx
    fi
  }

  _nx_pnpx() {
    if (( CURRENT > 2 )) && [[ $words[2] == nx ]]; then
      shift words; (( CURRENT-- )); _nx
    fi
  }

  compdef _nx nx
  compdef _nx_pnpx pnpx
  # zsh-npm-scripts-autocomplete is deferred and registers its own pnpm completion when it loads,
  # so queue this behind it to take over pnpm.
  if (( $+functions[zsh-defer] )); then
    zsh-defer compdef _nx_pnpm pnpm
  else
    compdef _nx_pnpm pnpm
  fi
fi
