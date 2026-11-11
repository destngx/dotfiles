---
name: feature
description: Build a new feature as a sous worker, from the brief to a pushed branch, an open PR and a filed report. Use when a sous brief (SOUS_TASK_ID is set) asks to add, build, support or extend behaviour, such as "add a CSV export button to the transactions page" or "implement the feature in your brief". Not for fixing a reported bug (bug-fix), for a task that only answers a question (writing-a-report), or for the owner's own sessions with no sous task.
---

<!-- Adapted from the feature playbook (skills/poteto-mode/playbooks/feature.md) and the verify-and-ship guide in pstack, https://github.com/cursor/plugins/tree/main/pstack, MIT License, Copyright (c) 2026 Lauren Tan. -->

# feature

A sous worker builds one feature for one task. The task starts from a brief that sous wrote, and it ends at ready: a pushed branch, an open PR and a report with evidence. The worker never merges. After a reviewer passes the work, the engine applies the merge rules and lands it or asks the owner.

## When to use it

Use this runbook when `SOUS_TASK_ID` is set and the brief asks for new or extended behaviour, such as a new screen, flag, endpoint or option. A brief that asks to fix wrong behaviour goes to `bug-fix`. A brief that asks a question and changes no file goes to `writing-a-report`.

## Steps

1. **Read the brief.** Run `sous task show "$SOUS_TASK_ID"` and read `.brief`. It holds the owner's words, the goal, the repo, the branch and base, the scope (`write` and `deny` paths), the context, the done condition, the verify commands, the timebox, the forbidden actions and the report shape. Compare the branch and base with the brief you were started with. If they differ, or a field you need is empty, do not guess. File `sous task report "$SOUS_TASK_ID" --status blocked --summary "<what is missing or differs>"` and stop.
2. **Get the worktree with the `gwf` skill.** When `.worker.worktree` in `sous task show` names a worktree and your working directory is inside it, stay there. Otherwise run `cd "$(gwf create <branch> <base>)"` with the brief's branch and base. If `gwf` prints `skipped untrusted .gwf/setup` or `.gwf/setup failed`, report `blocked` with the command the owner runs from the worktree, `gwf trust`. Do not install dependencies another way.
3. **Read the repo's rules.** Read the repo's `AGENTS.md` and the files the goal touches. Find how the repo already solves the nearest problem, and follow that pattern. Note which of the repo's own verify commands cover the code you will change, such as its test, lint, typecheck and build targets. You run those as well as the brief's `verify` list.
4. **Decide the design before you write code.** Name the data shape, the files you will change and how you will prove the feature works. Keep every change inside the brief's `scope.write` paths and outside `scope.deny`. When the goal needs a path outside the scope, or a choice the brief does not settle, see "Decisions" below.
5. **Build in small units.** Make one change, run the narrowest check that covers it, then commit. Write conventional commits in the repo's style. Commits carry no agent name, no task ID and no `Co-Authored-By` line. Add tests for the new behaviour next to the existing tests for that code.
6. **Record progress.** At each real decision or finished unit, run `sous task note "$SOUS_TASK_ID" "<one line>"`. A relaunched worker and the reviewer read these notes.
7. **Verify on the real thing.** Run every command in the brief's `verify` list and the repo's own verify commands from the worktree root, exactly as written. Then check the done condition itself against the running code: run the CLI, call the endpoint, or drive the screen with the app's verify skill when the repo has one. A build that compiles proves nothing about the feature. When a check cannot run, say so in the report. Do not count it as a pass.
8. **Open the PR and report.** Follow the `opening-a-pr` runbook. It reruns the verify commands at the final commit, pushes the branch, opens a ready PR and files `sous task report "$SOUS_TASK_ID" --status ready` with the evidence, head SHA and PR URL.
9. **Stop.** Do not merge, do not watch the PR, and do not remove the worktree. The engine lands the work after review and cleans up.

### Decisions

Decide a choice yourself only when the brief, the repo's patterns or the code settle it. Record each one with `sous task note "$SOUS_TASK_ID" "decision: <what you chose>, because <why>. To reverse: <how>"`, so it reaches the morning digest. Never decide these yourself. Report `blocked` with the question, the real options and your recommendation instead:

- a change outside the brief's scope, or a goal that grew
- a product choice the brief leaves open, where either answer changes what the owner gets
- anything irreversible: a production change, a message sent, money spent, data deleted, a force-push

### Rerun after a failed landing

When the task is a rerun because the landing rebase conflicted (`rebase-merge` prepare exit 3), follow "Rerun after a landing conflict" in the `rebase-merge` skill instead of building again: fetch, rebase onto `origin/<base>`, resolve, rerun the verify commands, and report the new head with the conflicted files listed. Use only that section, not the script, and never force-push.

### Timebox

The brief's `timebox` is a hard stop. When it runs out, or your inbox says "timebox reached, report what you have", commit what works, push it, and file `--status partial` with what is done, what is left and the evidence so far. Do not run on. When the doorbell `[sous] inbox` arrives, read it with `sous inbox --agent "task-$SOUS_TASK_ID"` and acknowledge the events you handled with `--ack <seq>`.

## Done when

All of these hold, and anyone can check them:

- `sous task show "$SOUS_TASK_ID" | jq -r .state` prints `ready` or a later state (`reviewing`, `landing`, `landed`, `waiting`).
- `.report.head` equals `git rev-parse HEAD` in the worktree and `git ls-remote origin "refs/heads/<branch>"`.
- `gh pr view <branch> --json state,isDraft,baseRefName` shows `OPEN`, `false` and the brief's base.
- `.report.evidence` lists every verify command with its exit code and output, and each one exited 0.
- `git diff --name-only "origin/<base>...HEAD"` lists only paths inside `scope.write`, none inside `scope.deny`, and no `fleet.toml`.

## Verify commands

Run these from the worktree root. `<base>` and `<branch>` come from the brief.

```sh
sous task show "$SOUS_TASK_ID" | jq '.brief.verify[]'        # the brief's verify list; run each one as written
git status --short                                            # empty: everything is committed
git diff --name-only "origin/<base>...HEAD"                   # every path is in scope
git rev-parse HEAD; git ls-remote origin "refs/heads/<branch>" # the same SHA twice
gh pr view <branch> --json url,state,isDraft,baseRefName,headRefOid
sous task show "$SOUS_TASK_ID" | jq '{state, report}'
```

## Known pitfalls

- **Ending the turn without a report.** While the task is open, the Stop hook blocks your turn from ending. After three blocks it lets one stop through and the engine marks the task stale. File a report, even `blocked` or `partial`, before you stop.
- **Your own claim is not evidence.** The reviewer reruns your verify commands in a fresh session. Paste the commands you ran and their real output, and make sure they run from the worktree root with no setup that only your session had.
- **Widening the scope.** A refactor you noticed, a dependency bump or a fix to nearby code is a follow-up. Put it in the report summary as a proposal, not in this diff. A lesson about the repo or this runbook is also a follow-up, proposed as its own PR.
- **Editing `fleet.toml`.** The plugin blocks edits to any `fleet.toml`, and the engine refuses to merge a diff that touches one. Never work around the block.
- **Installing tools.** Never install a tool or run `nix-rebuild`. When a tool is missing, report `blocked` and name it.
- **Merging.** Never run `gh pr merge`, push to the base branch, or run the `rebase-merge` skill. The engine lands the work.
