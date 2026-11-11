---
name: rebase-merge
description: Land a feature branch on main locally with linear history - rebase the branch onto origin/main, fast-forward main to it (no merge commit), push, watch the deploy, then remove the worktree and branch. Use whenever the user asks to merge finished work into main, in any wording - "merge", "merge it", "merge rebase", "rebase-merge", "proceed merge", "merge no ff" (main takes no merge commits, so no-ff requests land here too), "commit push and merge" (commit first, then run this skill) - or to land a branch/PR on main without the GitHub merge button. Not for merging main into a feature branch.
argument-hint: '[branch] (defaults to the current branch)'
---

# Rebase merge to main

Lands a branch on `main` the way GitHub's "Rebase and merge" would, but from the local checkout. `main` only
fast-forwards: the repo ruleset rejects merge commits ("Merge commits are not allowed in this repository"), so
`git merge --no-ff` is never used, even when the user says "no ff". The user asking for a rebase merge (by
slash command or in plain words such as "merge rebase") is their approval to push to `main`, to force-push the
feature branch with `--force-with-lease`, and to delete the branch (local and remote) and its worktree once the
merge and deploy are verified.

Branch: `$ARGUMENTS`, or the current branch when empty.

The base branch is the repo's default branch (`origin/HEAD`), or `main` when origin has none set. When the user
names another base ("merge it into release"), pass `--base <branch>` to prepare, land and cleanup. Every step
below that says `main` means the base. Each of those three steps prints `base=<branch>` first, so check that it is
the branch you meant.

When the request also asks for a commit ("commit push and merge"), commit the finished work in the branch's
worktree first, then start at step 1. The script pushes the branch itself, so do not push by hand.

`scripts/rebase-merge.sh` (installed at `~/.agents/skills/rebase-merge/scripts/rebase-merge.sh`) runs every git, gh
and Vercel command. Do not run those steps by hand. Each subcommand prints `key=value` lines and exits with a code that
says what to do next. Your part is the decisions between subcommands: which checks to rerun, whether the live site
is right, and which leftover processes to stop. The header of the script lists every exit code.

Run it exactly as written below, from a checkout's root, with no `cd` or env prefix in the same command. This is a
global skill, so each repo grants the push permission in its own `.claude/settings.json` with the allow rule
`Bash(bash ~/.agents/skills/rebase-merge/scripts/rebase-merge.sh *)`. That rule is the permission to push to `main`.
When a repo has no such rule, the push asks the user first. The monorepo's `main` ruleset rejects force pushes and
deleting `main` on the server. The script's tests are in `scripts/rebase-merge.test.sh`. Run them with `bash` after
changing the script.

## Steps

1. **Prepare.** From the branch's worktree (or from anywhere, naming the branch):

   ```sh
   bash ~/.agents/skills/rebase-merge/scripts/rebase-merge.sh prepare [branch] [--base <branch>]
   ```

   It refuses a dirty worktree, a branch with no commits and a branch in the primary checkout (exit 2). A change
   to `go.work.sum` alone does not count: Go rewrites it whenever a build downloads a module, so the script restores
   it and prints `discarded=<path>`, here and in cleanup (the worktree and the primary checkout). It
   rebases onto `origin/main` and pushes the branch with `--force-with-lease -u`. The push lets GitHub mark the
   PR merged, and lets `git branch -d` in cleanup check against the pushed copy.
   - Exit 2 means a precondition failed. Report it. For uncommitted changes, ask the user to commit first.
   - Exit 3 means the rebase conflicted. The script aborted it, so the branch is unchanged. Report the
     `conflict=` files and stop. Do not resolve conflicts silently. The fix is a rerun of the task, which follows
     "Rerun after a landing conflict" below.
   - `rewritten=yes` means `main` moved and the commits changed. Decide which checks the new base affects (the
     tests, lint and build of the projects the branch touches, plus any project that `main`'s new commits change
     under it). Run them in the worktree before landing. Fix or report failures, and do not land a red branch.

2. **Land.**

   ```sh
   bash ~/.agents/skills/rebase-merge/scripts/rebase-merge.sh land [branch] [--base <branch>]
   ```

   It pushes the branch tip to `main`. The push is a fast-forward or nothing, because there is no force. Then it
   checks that `origin/main` equals the tip and waits for the PR to show `MERGED`.
   - Exit 4 means `origin/main` moved after prepare, or another session's push to `main` landed during this one
     (GitHub answers that with `cannot lock ref`). Go back to step 1.
   - Exit 5 means a ruleset rejected the push (for example, required reviews or status checks). Report the exact
     message and stop. Do not try to bypass it.
   - `pr_state=OPEN` after the retries usually means GitHub is slow. Check again with
     `gh pr view <branch> --json state` before reporting it.

   Keep `old_main` and `vercel_apps` from the output for the next steps.

3. **Watch the deploy.** If `vercel_apps` is empty, go to step 4.

   ```sh
   bash ~/.agents/skills/rebase-merge/scripts/rebase-merge.sh deploy
   ```

   For each app with a `vercel.json`, it waits for the production deployment of the new `main` SHA. It uses the
   Vercel CLI read-only (it never runs `vercel link`). `SKIPPED` means the app's ignored build step found the app
   unaffected, which is fine. Exit 7 means a deploy failed (the build log is on stderr) or never finished. Exit 2
   means `vercel` is not on PATH. In that case, ask the user instead of installing it.

   For each `READY` app, check the live site yourself. Find the routes the change affects
   (`git diff --name-only <old_main>..origin/main`). Open them on the production domain, and confirm that they
   return 200 and show the change. If the deploy failed or the site is wrong, stop, report it, and skip cleanup,
   so the worktree stays available for a fix.

4. **Clean up.** Only after the merge is verified and the deploy (if any) is good. First `cd` to the primary
   checkout, so your shell is not inside the worktree being removed:

   ```sh
   bash ~/.agents/skills/rebase-merge/scripts/rebase-merge.sh cleanup <branch> [--base <branch>]
   ```

   It refuses a branch that is not on `origin/main` (exit 6). It stops the worktree's Nx daemon, runs
   `gwf rm -y -D <branch>` (or `git worktree remove` and `git branch -d` without `gwf`), and deletes the remote
   branch. It pulls the primary checkout only when it is on `main` and clean. Otherwise it prints
   `pulled=skipped`, because another session is working there. Ignored files (`node_modules`, build output) go
   with the worktree, which is expected.
   - Exit 8 means `gwf rm` skipped the worktree. For each process holding it, the script prints
     `in_use=<pid> cwd=<dir> command=<command>`. Stop a process only if your own runs started it from this
     worktree's path (a dev server, a test engine). Then rerun cleanup. Never stop the user's processes or
     anything running from the primary checkout. If the worktree has uncommitted changes, or a process is not
     yours, report it. Never force-remove the worktree or use `git branch -D`.
   - Exit 6 from the pull means `--ff-only` failed. Report it. Never merge or rebase the primary checkout.
   - Exit 1 with `git fetch origin failed` or `checking origin/<branch> failed` means git could not reach origin.
     The script sets SSH timeouts, so a stalled connection fails within about a minute instead of hanging. Rerun
     cleanup. It also works after the local branch is gone, using origin's copy, and deletes what is left. Never
     delete the remote branch by hand.

5. **Report.** The new `main` SHA, the PR state, the deploy URL and status, what the live check covered, what was
   cleaned up, and whether the primary checkout was pulled.

## Rerun after a landing conflict

When a landing stopped at prepare with exit 3, the branch is unchanged and the task is rerun to fix the conflict.
The rerun worker (a sous worker running `feature` or `bug-fix`) does this in the branch's worktree, by hand, not
with the script: prepare force-pushes the branch, and a rerun never force-pushes.

1. **Fetch.** `git fetch origin`.
2. **Rebase.** `git rebase origin/main` (or the brief's base). Write down every file git reports as conflicted.
3. **Resolve.** Resolve each conflict so that both `main`'s change and the branch's change survive. When the two
   cannot both hold, or the right answer is a product choice, stop and ask (`sous task ask`) instead of picking a
   side. Then `git add` the file and `git rebase --continue`. Never use `-X ours`, `-X theirs` or
   `git checkout --ours/--theirs` to make a conflict go away.
4. **Verify.** Rerun every verify command from the brief, plus the repo's checks for the projects the branch and
   `main`'s new commits touch, from the worktree root. Do not report a red branch.
5. **Push without force.** The rebased branch no longer fast-forwards from its pushed copy, so it cannot go onto
   the old branch name without a force. Keep the local branch name and push the rebased head to a new remote
   branch, leaving the old one alone:

   ```sh
   git push -u origin HEAD:refs/heads/<branch>-rebased
   ```

   Whoever pushes for the task runs it: the worker through `opening-a-pr`, or the machine mate when the brief says
   the worker does not push, in which case the worker names the new branch in its report. Never `--force` or
   `--force-with-lease`.

   A worker that follows `opening-a-pr` reads `<branch>` as `<branch>-rebased` in its push, PR and done steps:
   - step 7 pushes with the command above, not `git push -u origin <branch>`
   - step 8 checks `gh pr view <branch>-rebased` and opens a new PR with
     `gh pr create --base <base> --head <branch>-rebased`. It never reuses the old PR, whose head is the old branch.
   - the done checks compare `git ls-remote origin refs/heads/<branch>-rebased` with `git rev-parse HEAD`

   Leave the old PR and the old branch as they are. Closing them is for whoever lands the work, not the rerun.
6. **Report.** The new head SHA (`git rev-parse HEAD`), the new branch name and that it replaces the old one, the
   new PR URL and the old PR it replaces, the list of conflicted files with one line each on how it was resolved,
   and the verify output. A conflict that the report does not list counts as resolved silently.
