#!/usr/bin/env bash
# Shared by the skill tools. Source it, then call skills_layout <repo root>.

# Sets SKILLS_DIR (the skills) and SKILL_LINKS_DIR (the Claude Code links to them), both relative to the repo root:
#   .agents/skills and .claude/skills   in a project repo (the default)
#   agents/skills and claude/skills     in the dotfiles repo, which home-manager links to ~/.agents and the Claude
#                                       config dir, so its skills are global
skills_layout() {
  if [[ ! -d "$1/.agents/skills" && -d "$1/agents/skills" ]]; then
    SKILLS_DIR=agents/skills
    SKILL_LINKS_DIR=claude/skills
  else
    SKILLS_DIR=.agents/skills
    SKILL_LINKS_DIR=.claude/skills
  fi
}

# Prints the repo root: the --root argument when given, else the top level of the current directory's git repo.
skills_root() {
  if [[ -n "${1:-}" ]]; then
    (cd "$1" && pwd)
  else
    git rev-parse --show-toplevel
  fi
}

# Prints the global skills directory: SKILL_GLOBAL_DIR when set, else ~/.agents/skills, which home-manager links to
# the dotfiles repo's agents/skills.
skills_global_dir() {
  echo "${SKILL_GLOBAL_DIR:-$HOME/.agents/skills}"
}

# Prints "<scope> <dir>" for every skill (a directory with a SKILL.md) the repo at $1 sees: its own skills with scope
# repo, then the global skills with scope global. A repo skill hides a global skill with the same name. Calls
# skills_layout, so SKILLS_DIR and SKILL_LINKS_DIR are set afterwards.
skills_dirs() {
  local d names=" "
  skills_layout "$1"
  for d in "$1/$SKILLS_DIR"/*/; do
    [[ -f "$d/SKILL.md" ]] || continue
    names+="$(basename "$d") "
    echo "repo ${d%/}"
  done
  for d in "$(skills_global_dir)"/*/; do
    [[ -f "$d/SKILL.md" && "$names" != *" $(basename "$d") "* ]] || continue
    echo "global ${d%/}"
  done
}
