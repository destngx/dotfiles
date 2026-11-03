---
name: writing-a-report
description: Answer a sous investigate task with a report that stands on its own. Read the brief, gather evidence without changing the project, write the findings with the commands and their output, list every decision left for the owner or say there is none, and file it with sous task report. Use when a sous brief asks a question rather than a change, such as "find out why the nightly build got slower, report only", "compare two hosting options" or "summarise this contract PDF". Not for a monitor alert (investigating-an-alert) and not for changing code (feature or bug-fix).
---

<!-- Adapted from the investigation playbook (skills/poteto-mode/playbooks/investigation.md) in pstack, https://github.com/cursor/plugins/tree/main/pstack, MIT License, Copyright (c) 2026 Lauren Tan, and from the scout-completion and captain-hold-lifecycle skills in firstmate, https://github.com/kunchenguid/firstmate, MIT License, Copyright (c) 2026 Kun Chen. -->

# writing-a-report

A sous worker answers one question for one task. The deliverable is a report that someone who never saw the work can read and act on: the answer, the evidence behind it, and every decision it leaves for the owner. A report can recommend a change, but it never makes one. A fix is a new ship task that the owner approves.

## When to use it

Use this runbook when `SOUS_TASK_ID` is set and the brief asks a question: why something happens, how something works, which option to pick, or what a document says. `sous task show "$SOUS_TASK_ID" | jq -r .shape` usually prints `investigate`. An alert from a monitor goes to `investigating-an-alert` instead.

When the brief's shape is `ship` and it asks for the report as a file in a repo, such as a note in `obsidian-vaults`, writing that file is a change. Write it in the brief's gwf worktree with the `gwf` skill, commit it, and finish with the `opening-a-pr` runbook instead of step 7 below.

## Steps

1. **Read the brief.** Run `sous task show "$SOUS_TASK_ID"` and read `.brief`: the owner's words, the goal, the repo or folder, the context, the done condition, the verify commands, the timebox, the forbidden actions and the report shape. The report shape and the done condition are your rubric, because the reviewer grades the report against them. If the question is unclear or a field you need is empty, file `sous task report "$SOUS_TASK_ID" --status blocked --summary "<what is unclear>"` and stop.
2. **Stay read-only.** Read files, logs, history and docs in place. Do not edit the project. When you must run code that writes files, such as a build or a repro, work only in the task's scratch worktree. Use `.worker.worktree` when it is set, or make one with the `gwf` skill from the brief's base, and record its path with `sous task note "$SOUS_TASK_ID" "scratch worktree: <path>"`. Never commit in a scratch worktree. Sous removes it after the report only when it has no commits.
3. **Gather evidence.** Find how the code or system works before you ask why. Read the code path, then the history with `git log --follow -p -- <file>`, `git blame -L <start>,<end> <file>` and `gh pr view <number>` for the PRs those commits name. Run the commands that show the behaviour, and keep each command with its output. For a document, cite the page or section of every claim.
4. **Separate facts from guesses.** For each finding, say whether you observed it, read it in a cited source, or inferred it. For a cause, name the trigger, the condition that hides or exposes it, and the visible symptom. Name what would prove your leading answer wrong, and check it.
5. **Record progress.** At each finding or dead end, run `sous task note "$SOUS_TASK_ID" "<one line>"`.
6. **Write the report.** Write it to a file outside the repo, `report="${TMPDIR:-/tmp}/sous-$SOUS_TASK_ID-report.md"`, with these sections:
   - `## Answer` gives the answer in one to three sentences.
   - `## Findings` lists each finding with its source: a `file:line`, a commit, a PR, a page, or a command.
   - `## Evidence` holds the exact commands you ran and the parts of their output that matter.
   - `## Recommendation` names the change you would make, if any, as a draft brief: the goal, the repo, the done condition and the verify commands. For a choice between options, add a table of options and their costs.
   - `## Decisions for the owner` lists each open question with what it is, why it matters now, the real options and your recommendation with a one-line reason. When there are none, write `None.`
   - `## Unknowns` lists what you could not check and how that could change the answer.

   Use the `unslop` skill on the report.
7. **File the report.**

   ```sh
   sous task report "$SOUS_TASK_ID" --status ready \
     --summary "$(sed -n '/^## Answer/,/^## Findings/p' "$report" | sed '1d;$d')" \
     --evidence "$(cat "$report")"
   ```

   Use `--status ready` when the report answers the question, `partial` when the timebox ran out or part of the question is open, and `blocked` when you could not get the access or inputs you need. Every task gets a report, even an empty one.
8. **Stop.** Do not start the fix, open a PR, or create a task. The first mate turns a recommendation into a new task when the owner approves it.

### Timebox

When the brief's timebox runs out, or your inbox says "timebox reached, report what you have", write the report with what you have and file it as `partial`, with what is left in `## Unknowns`. When the doorbell `[sous] inbox` arrives, read it with `sous inbox --agent "task-$SOUS_TASK_ID"` and acknowledge the events you handled with `--ack <seq>`.

## Done when

- `sous task show "$SOUS_TASK_ID" | jq -r .state` prints `ready`, `partial` or `blocked`, not `running`.
- `.report.evidence` has all six sections, and `## Decisions for the owner` lists at least one decision or says `None.`
- Every finding names a source that resolves: the file and line exist, the commit is in `git log`, the command runs.
- `git status --short` in the project is unchanged from before the task, and a scratch worktree has no commits.

## Verify commands

```sh
sous task show "$SOUS_TASK_ID" | jq '.brief | {goal, done, verify, report}'
sous task show "$SOUS_TASK_ID" | jq '.brief.verify[]'     # run each one as written
grep -c '^## ' "$report"                                  # 6
grep -A3 '^## Decisions for the owner' "$report"
git -C <scratch worktree> log --oneline "origin/<base>..HEAD"  # empty
sous task show "$SOUS_TASK_ID" | jq '{state, report}'
```

## Known pitfalls

- **A question lost in prose.** A decision that sits in the findings but not in `## Decisions for the owner` is lost once the worktree is gone. List every one, and only real ones: a finding that needs no choice is not a decision.
- **A recommendation is not permission.** Even an obvious one-line fix waits for its own task and approval.
- **Confidence without evidence.** A finding without a source, or a cause that explains the failure but not the case that works, is a guess. Label it as one.
- **A report that needs the conversation.** The reader sees only the report. Spell out paths, commands and numbers. Do not refer to "above" or "the earlier run".
- **Ending the turn without a report.** The Stop hook blocks your turn while the task is open, and after three blocks the engine marks the task stale.
- **Writing to the project.** Do not fix typos, add logging or update docs you read along the way. Note them as follow-ups.
