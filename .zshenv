source "/home/destnguyxn/.rover/env"

git() {
  if [[ $# -gt 0 ]]; then
    command git "$@"
  else
    command git status
  fi
}
