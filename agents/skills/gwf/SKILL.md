---
name: gwf
description: Work in a gwf worktree for any task that writes files in a git repo. Use before the first edit, commit or branch for a fix, feature, refactor, rename, config or docs change, in any repo. Not for questions, reviews or read-only investigation that change no file.
---

# gwf

Every task that writes files in a git repo runs in its own worktree, made with `gwf`. Several sessions work in the same repos at once, and a worktree per task keeps their changes apart. Read-only work, such as answering a question or reviewing a diff, needs no worktree.

## Repo rules come first

Read the repo's `AGENTS.md` before you start. When it has its own worktree rules, as the monorepo's "Git Worktrees" section does, follow those rules where they differ from the steps below.

## Steps

1. **Check where you are.** Run `gwf ls` and `git status`. If the checkout has uncommitted changes that are not part of your task, leave them alone and do not edit next to them.
2. **Create the worktree.** Run `cd "$(gwf create <branch> <base>)"`. Take the branch and base from your brief or the user. When none is given, name the branch in the repo's style, or `<type>/<topic>` (for example `fix/rounding-total`) when the repo has none, and leave out the base so `gwf` uses origin's default branch. Branch names, commits and PRs never carry an agent name or marker. `gwf` puts the worktree at `<repo>-worktrees/<topic>` and prints its path.
3. **Check the branch is yours.** When `gwf` says the branch is already checked out somewhere, it prints that worktree's path. Work there only when your brief or the user named that worktree. Otherwise another session owns it, so stop and ask.
4. **Check the setup ran.** After it creates a worktree, `gwf` runs the repo's `.gwf/setup`, which installs dependencies, once the owner has trusted it. When `gwf` prints `skipped untrusted .gwf/setup` or `.gwf/setup failed`, stop and report it with the command the owner runs from the worktree: `gwf trust`. Do not install dependencies another way and do not run the setup script yourself.
5. **Work only in the worktree.** Edit, build, test and commit there. Use paths inside it, and never write to the primary checkout or another worktree.
6. **Clean up after the merge.** Only once the branch is merged, run `gwf rm -y -D <branch>` from the primary checkout. It removes the worktree, deletes the merged branch and prunes. Before the merge, leave the worktree in place.

## When gwf refuses

`gwf` refuses on purpose: it skips a worktree with uncommitted changes or one that another process uses, keeps a branch that is not fully merged, and will not create over an existing path. Report the refusal and its message. Never force past it with `git worktree remove --force`, `git branch -D`, `rm -rf` or by editing in another checkout. The interactive forms, `gwf rm` without `-y`, `gwf gc` and `gwf trust`, are for the owner.
