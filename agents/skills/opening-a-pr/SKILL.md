---
name: opening-a-pr
description: Open the pull request for a sous ship task and file its ready report. Check the branch and base against the brief, rerun the verify commands at the final commit, push the branch, open a ready PR with gh, and report the head SHA and PR URL with sous task report. Use at the end of the feature and bug-fix runbooks, or when a sous worker is told "open the PR" or "push the branch and open a pull request". Not for merging or landing a branch, which the engine does after review, and not for reviewing a PR.
---

<!-- Adapted from the opening-a-PR playbook (skills/poteto-mode/playbooks/opening-a-pr.md) in pstack, https://github.com/cursor/plugins/tree/main/pstack, MIT License, Copyright (c) 2026 Lauren Tan. -->

# opening-a-pr

The last step of every sous ship task. The worker pushes its branch, opens one ready PR against the brief's base, and files the report that moves the task to ready. It does not merge. After the reviewer passes the work, the engine applies the merge rules and lands it with `rebase-merge` or `gh`, or parks a decision for the owner.

## When to use it

Use it at the end of the `feature` and `bug-fix` runbooks, at the end of a ship task from `writing-a-report`, or when a sous worker is asked to open its PR. `SOUS_TASK_ID` and `SOUS_TASK_TOKEN` must be set. Work only in the task's gwf worktree.

## Steps

1. **Check the branch and base.** Run `sous task show "$SOUS_TASK_ID" | jq '.brief | {repo, branch, base, verify}'`. Then check that `git branch --show-current` prints the brief's branch and that `pwd` is inside the task's worktree. If either differs, file `--status blocked` with what differs and stop.
2. **Check the tree.** `git status --short` must print nothing. Commit any finished work. Leave out debug edits, scratch files and generated output the repo does not track.
3. **Check the commits.** Run `git log --oneline "origin/<base>..HEAD"`. Each commit is a conventional commit in the repo's style, such as `feat(wealth-management): add CSV export to transactions`, and tells one step of the story. Commits, the branch and the PR carry no agent name, no task ID and no `Co-Authored-By` line. Before the first push you may reorder or squash commits with `git rebase origin/<base>` and fixups. After the branch is on the remote, add commits instead, because force-pushing is forbidden.
4. **Update from the base before the first push.** Run `git fetch origin <base>`. If `git merge-base --is-ancestor origin/<base> HEAD` fails and the branch is not pushed yet, run `git rebase origin/<base>`. Stop and report `blocked` with the conflicting files if the rebase conflicts, after `git rebase --abort`.
5. **Check the scope.** `git diff --name-only "origin/<base>...HEAD"` must list only paths inside the brief's `scope.write`, none in `scope.deny`, and no `fleet.toml`.
6. **Rerun the verify commands at the final commit.** Run every command in the brief's `verify` list and the repo's own checks for the projects you touched, from the worktree root, exactly as written. Write each command, its exit code and the end of its output to an evidence file outside the repo:

   ```sh
   evidence="${TMPDIR:-/tmp}/sous-$SOUS_TASK_ID-evidence.txt"
   : >"$evidence"
   run() { { printf '$ %s\n' "$1"; bash -c "$1" 2>&1 | tail -n 40; printf 'exit=%s\n\n' "${PIPESTATUS[0]}"; } >>"$evidence"; }
   run 'pnpm exec nx test wealth-management'   # once per verify command
   printf 'head=%s\n' "$(git rev-parse HEAD)" >>"$evidence"
   ```

   Add the done-condition check from the feature or bug-fix runbook, such as the repro before and after. Any command that exits non-zero means the task is not ready. Fix it, or report `partial` or `blocked`.
7. **Push the branch.** Run `git push -u origin <branch>`. Never push to the base branch and never use `--force` or `--force-with-lease`. Check that `git ls-remote origin "refs/heads/<branch>"` prints the same SHA as `git rev-parse HEAD`.
8. **Open the PR.** If `gh pr view <branch> --json url,state` already shows an open PR, reuse it and update its body with `gh pr edit`. Otherwise write the body to a file and run:

   ```sh
   gh pr create --base <base> --head <branch> --title "<type>(<scope>): <subject>" --body-file "$body"
   ```

   Open it ready, never as a draft. The title follows the repo's conventional commit style with no trailing period. The body is a briefing a reviewer reads in a minute, with these `##` sections in order, each dropped when it has nothing to say:
   - `## Why` gives the problem and the approach in one to three sentences.
   - `## What changed` has one to three bullets.
   - `## Scope` says what the PR covers and what it leaves out.
   - `## Verification` names each command run and its result.

   Read the PR back with `gh pr view <branch> --json url,state,isDraft,baseRefName,headRefOid` and check that it is open, not a draft, on the right base, and that its head is your SHA.
9. **File the report.**

   ```sh
   sous task report "$SOUS_TASK_ID" --status ready \
     --summary "<what changed and why, two or three sentences, plus any follow-ups>" \
     --evidence "$(cat "$evidence")" \
     --head "$(git rev-parse HEAD)" \
     --pr "<PR URL>"
   ```

   The command prints one line. Check it with `sous task show "$SOUS_TASK_ID" | jq '{state, report}'`.
10. **Stop.** Do not merge, do not wait on CI, and do not run `gwf rm`. The reviewer reruns your verify commands, and the engine lands the work and cleans up.

## Done when

- `sous task show "$SOUS_TASK_ID" | jq -r .state` prints `ready` or a later state.
- `.report.head`, `git rev-parse HEAD` and `git ls-remote origin "refs/heads/<branch>"` show the same SHA.
- `.report.pr` is the URL that `gh pr view <branch> --json url` prints, and the PR is `OPEN`, not a draft, against the brief's base.
- `.report.evidence` lists every verify command with `exit=0`, and ends with `head=<the same SHA>`.

## Verify commands

```sh
git branch --show-current
git status --short
git diff --name-only "origin/<base>...HEAD"
git rev-parse HEAD; git ls-remote origin "refs/heads/<branch>"
gh pr view <branch> --json url,state,isDraft,baseRefName,headRefOid
sous task show "$SOUS_TASK_ID" | jq '{state, report}'
```

## Known pitfalls

- **Evidence from an older commit.** If you commit after running the checks, run them again. The reviewer checks the head you report.
- **A draft PR.** `gh pr create` with `--draft` or a repo template that opens drafts leaves the PR in draft. Run `gh pr ready <branch>` and read it back.
- **No GitHub remote.** When `gh repo view` fails because the repo has no GitHub remote, you cannot open a PR. Report `blocked` with that reason. Do not create a remote or a repo.
- **A rejected push.** A branch protection or hook that rejects the push is a refusal. Report its exact message as `blocked`. Never bypass it with `--no-verify` or a force-push.
- **The `sous` command fails.** When the engine does not answer, `sous task report` fails with a message on stderr. Wait a minute and run it again. Do not end the turn until a report is filed, and never write to `~/.local/state/sous/` yourself.
- **Merging.** Never run `gh pr merge`, `gh pr merge --auto`, the `rebase-merge` skill or a push to the base branch, even when the checks are green.
