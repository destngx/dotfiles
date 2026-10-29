#!/usr/bin/env bash
# Helpers for the scaffold scripts of skill behaviour evals. eval.sh copies this file to evals/_lib/sandbox.sh in the
# staged copy of the skill, so a scaffold at evals/behavior/<case>/scaffold.sh loads it with:
#
#   source "$(dirname "${BASH_SOURCE[0]}")/../../_lib/sandbox.sh"
#
# A scaffold runs in the run's empty workspace, which becomes the agent's cwd, with HOME set to the run's temp home.
set -euo pipefail

SANDBOX_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SANDBOX_SKILL="$(basename "$SANDBOX_SKILL_DIR")"

sandbox_git() { git -c user.email=eval@example.com -c user.name=eval -c core.hooksPath=/dev/null "$@"; }

# On macOS /usr/bin/git is an xcrun shim that writes a cache under /var/folders, which the eval sandbox denies, and
# the sandbox cannot read Xcode.app either, so git fails in the agent's shell. That shell's PATH starts with
# $HOME/.nix-profile/bin, so copy the real git there with its libexec and share dirs (Apple's git finds them relative
# to the binary). Every sandbox_* helper that needs git calls this.
sandbox_real_git() {
  [[ "$(uname)" == Darwin && "$(command -v git)" == /usr/bin/git ]] || return 0
  [[ -x "$HOME/.nix-profile/bin/git" ]] && return 0
  local prefix
  prefix="$(dirname "$(dirname "$(xcrun --find git)")")"
  mkdir -p "$HOME/.nix-profile/bin" "$HOME/.nix-profile/libexec" "$HOME/.nix-profile/share"
  cp "$prefix/bin/git" "$HOME/.nix-profile/bin/"
  cp -R "$prefix/libexec/git-core" "$HOME/.nix-profile/libexec/"
  cp -R "$prefix/share/git-core" "$HOME/.nix-profile/share/"
}

# Builds a repo shaped like this monorepo in the workspace:
#   origin.git  bare remote standing in for GitHub
#   primary/    the primary checkout on main, with the skill under test committed at .agents/skills/<skill>
#               (without its evals) and a feature.txt
#   wt/         a worktree on <branch> (default feat/x) with one commit that changes feature.txt
sandbox_repo() {
  local branch="${1:-feat/x}" ws
  ws="$(pwd)"
  sandbox_real_git
  git init -q --bare -b main "$ws/origin.git"
  git clone -q "$ws/origin.git" "$ws/primary" 2>/dev/null
  git -C "$ws/primary" config user.email eval@example.com
  git -C "$ws/primary" config user.name eval
  git -C "$ws/primary" config core.hooksPath /dev/null
  mkdir -p "$ws/primary/.agents/skills"
  cp -R "$SANDBOX_SKILL_DIR" "$ws/primary/.agents/skills/$SANDBOX_SKILL"
  rm -rf "$ws/primary/.agents/skills/$SANDBOX_SKILL/evals"
  printf '# demo\n' >"$ws/primary/README.md"
  printf 'v1\n' >"$ws/primary/feature.txt"
  git -C "$ws/primary" add -A
  git -C "$ws/primary" commit -qm "chore: base"
  git -C "$ws/primary" push -q origin main
  git -C "$ws/primary" worktree add -q -b "$branch" "$ws/wt" origin/main 2>/dev/null
  printf 'v2 from %s\n' "$branch" >"$ws/wt/feature.txt"
  git -C "$ws/wt" add -A
  git -C "$ws/wt" commit -qm "feat: update feature text"
}

# Pushes a commit that sets <file> to <content> on origin/main from a scratch clone, so the branch falls behind.
sandbox_advance_main() {
  local file="$1" content="$2" ws
  ws="$(pwd)"
  git clone -q "$ws/origin.git" "$ws/.scratch" 2>/dev/null
  printf '%s\n' "$content" >"$ws/.scratch/$file"
  git -C "$ws/.scratch" add -A
  sandbox_git -C "$ws/.scratch" commit -qm "chore: change $file on main"
  git -C "$ws/.scratch" push -q origin main
  rm -rf "$ws/.scratch"
}
