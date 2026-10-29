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
