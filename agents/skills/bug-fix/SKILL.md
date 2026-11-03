---
name: bug-fix
description: Fix a reported bug as a sous worker. Reproduce it, prove the cause with evidence, commit a failing check before the fix, then push, open a PR and file the report. Use when a sous brief (SOUS_TASK_ID is set) asks to fix broken, wrong or regressed behaviour, such as "fix the rounding bug in the portfolio total" or "market-data-server returns stale quotes after midnight, fix it". Not for new behaviour (feature), for finding a cause without changing code (writing-a-report), or for a monitor alert (investigating-an-alert).
---

<!-- Adapted from the bug-fix playbook (skills/poteto-mode/playbooks/bug-fix.md) and the tdd skill in pstack, https://github.com/cursor/plugins/tree/main/pstack, MIT License, Copyright (c) 2026 Lauren Tan, and from the diagnostic-reasoning skill in firstmate, https://github.com/kunchenguid/firstmate, MIT License, Copyright (c) 2026 Kun Chen. -->

# bug-fix

A sous worker fixes one bug for one task. Every line it ships traces to evidence from running the code. The task ends at ready: a pushed branch whose history shows the failing check before the fix, an open PR and a report. The worker never merges. After a reviewer passes the work, the engine applies the merge rules and lands it or asks the owner.

## When to use it

Use this runbook when `SOUS_TASK_ID` is set and the brief says something is broken, wrong or slower than it was, and asks for a fix. A brief that asks only for the cause goes to `writing-a-report`. An alert from a monitor goes to `investigating-an-alert`, and its fix is a later task.

## Steps

1. **Read the brief.** Run `sous task show "$SOUS_TASK_ID"` and read `.brief`: the owner's words, the goal, the repo, the branch and base, the scope, the context, the done condition, the verify commands, the timebox and the forbidden actions. When the context holds an earlier investigation's report, start from its findings and check them, rather than starting over. If the branch or base differs from the brief you were started with, or a field you need is empty, file `sous task report "$SOUS_TASK_ID" --status blocked --summary "<what is missing or differs>"` and stop.
2. **Get the worktree with the `gwf` skill.** When `.worker.worktree` names a worktree and your working directory is inside it, stay there. Otherwise run `cd "$(gwf create <branch> <base>)"` with the brief's branch and base. If `gwf` reports a skipped or failed `.gwf/setup`, report `blocked` with the command the owner runs from the worktree, `gwf trust`.
3. **Write down the observed behaviour.** Start from what the user sees, not from an error string or a guess about the code. Record the expected behaviour, the observed behaviour, the setup, the inputs and how often it happens.
4. **Reproduce it yourself.** Drive the real path the user takes: the CLI command, the HTTP call, the screen through the app's verify skill. If it does not reproduce, tighten the conditions or add logging until it does. When a faithful repro is not possible or not safe, write down why and use the closest path, and say in the report that it is not the same evidence. Keep the exact repro command, because it becomes the regression check.
5. **Find the cause by elimination.** List the candidate causes. Compare the failing path with a path where the behaviour works, and find the earliest point where they differ in inputs, state, timing or control flow. Read the history of the code with `git log --follow -p -- <file>` and `git blame -L <start>,<end> <file>`. Do not blame the most recent nearby change without evidence. Keep three facts apart:
   - the trigger, the input or event that starts the fault
   - the masking condition, the state, cache, timing or config that hides or exposes it
   - the symptom, what the user sees
6. **Test the explanation.** Name the smallest change that should flip the outcome if your explanation is right, make it, and record whether the symptom goes away. Name the observation that would prove you wrong, and look for it. Keep results that contradict you in your notes. The explanation must account for both the failing path and the working one.
7. **Commit the failing check first.** When the code has a cheap local test path, add the smallest test that encodes the intended behaviour, run it, and confirm it fails for the reason you found. Commit it on its own. When a test would need broad mocks, slow infrastructure or production-only state, keep the repro command as the check instead, and say so in the report. Prefer no new test to a bad test.
8. **Fix the cause.** Make the smallest change the evidence supports, inside the brief's `scope.write` paths. A change that "might help" is a guess and does not ship. When evidence refutes a guess, revert what it added. Rerun the failing check and confirm it passes. Commit the fix on top of the check, so the history shows the check failing before the fix.
9. **Record progress.** At each hypothesis ruled out and each commit, run `sous task note "$SOUS_TASK_ID" "<one line>"`.
10. **Verify.** Run every command in the brief's `verify` list and the repo's own verify commands (test, lint, typecheck, build for the projects you touched) from the worktree root, exactly as written. Run the original repro again. Unit tests show that a branch of code behaves, not that the bug is gone.
11. **Open the PR and report.** Follow the `opening-a-pr` runbook. The evidence must hold the repro output before the fix and after it, verbatim.
12. **Stop.** Do not merge, do not watch the PR, and do not remove the worktree.

### Decisions

Decide a choice yourself only when the brief, the repo or the evidence settles it, and record it with `sous task note "$SOUS_TASK_ID" "decision: <what you chose>, because <why>. To reverse: <how>"`. Report `blocked` with the question, the real options and your recommendation when the fix needs a path outside the scope, changes behaviour the owner may rely on, or needs anything irreversible, such as a data migration in production or a force-push.

### Timebox

When the brief's timebox runs out, or your inbox says "timebox reached, report what you have", stop. Commit what you have, push it, and file `--status partial` with the repro, what you ruled out, what is left and the evidence so far. When the doorbell `[sous] inbox` arrives, read it with `sous inbox --agent "task-$SOUS_TASK_ID"` and acknowledge the events you handled with `--ack <seq>`.

## Done when

- `sous task show "$SOUS_TASK_ID" | jq -r .state` prints `ready` or a later state.
- `.report.evidence` holds the repro command with its failing output before the fix and its passing output after it, and every verify command with exit code 0.
- `git log --oneline "origin/<base>..HEAD"` shows the commit with the failing check before the commit with the fix, or the report says why there is no separate check.
- `.report.head` equals `git rev-parse HEAD` and the pushed branch, and `gh pr view <branch> --json state,isDraft,baseRefName` shows `OPEN`, `false` and the brief's base.
- `git diff --name-only "origin/<base>...HEAD"` lists only paths in scope and no `fleet.toml`.

## Verify commands

```sh
sous task show "$SOUS_TASK_ID" | jq '.brief.verify[]'   # run each one as written
git log --oneline "origin/<base>..HEAD"                  # check commit, then fix commit
<repro>                                                   # the repro command from step 4, passes at HEAD
git diff --name-only "origin/<base>...HEAD"
gh pr view <branch> --json url,state,isDraft,baseRefName,headRefOid
sous task show "$SOUS_TASK_ID" | jq '{state, report}'
```

## Known pitfalls

- **Fixing the symptom.** A retry, a wider timeout or a null check that hides the fault is not a fix unless the evidence shows the cause is there. Name the cause in the report.
- **Mistaking the masking condition for the cause.** A cache or a race that makes the bug appear only sometimes may not start it. Show which one you changed and why that one.
- **A test that passes before the fix.** If the new test passes on the old code, it does not test the bug. Fix the test before you touch the code.
- **Ending the turn without a report.** The Stop hook blocks your turn while the task is open, and after three blocks the engine marks the task stale. File a report, even `blocked` or `partial`.
- **Widening the scope.** Other bugs you find go in the report as follow-ups, not in this diff.
- **Editing `fleet.toml`, installing tools, or merging.** The plugin blocks `fleet.toml` edits. Never install a tool or run `nix-rebuild`. Never run `gh pr merge`, push to the base branch or run the `rebase-merge` skill.
