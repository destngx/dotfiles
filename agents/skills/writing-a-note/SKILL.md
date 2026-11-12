---
name: writing-a-note
description: Write a note, report or study material into a knowledge repo such as obsidian-vaults as a sous worker, from the brief to a commit and a filed ready report. Read the brief, follow the vault's own layout, cite a source for every claim, verify the note and commit it, without pushing or opening a PR. Use when a sous brief (SOUS_TASK_ID is set) with shape ship and profile knowledge asks for a file in a vault, such as "write a note on Postgres MVCC in obsidian-vaults" or "write study material on VPC networking". Not for a question answered only in the report (writing-a-report) and not for changing code (feature or bug-fix).
---

# writing-a-note

A sous worker writes one note for one knowledge task. The task starts from a brief that sous wrote, and it ends at a commit and a ready report. The worker never pushes and never opens a PR. Its machine mate runs `sous task push`, and the engine lands the work after a reviewer passes it.

## When to use it

Use this runbook when `SOUS_TASK_ID` is set, `sous task show "$SOUS_TASK_ID" | jq -r .shape` prints `ship`, and the brief asks for a file in a knowledge repo: a note, a report kept in the vault, a summary of a document, or study material. The brief's profile is usually `knowledge`. A brief that asks a question and keeps the answer only in the report goes to `writing-a-report`. A brief that changes code goes to `feature` or `bug-fix`.

## Steps

1. **Read the brief.** Run `sous task show "$SOUS_TASK_ID"` and read `.brief`: the owner's words, the goal, the repo, the branch and base, the scope (`write` and `deny` paths), the context, the done condition, the verify commands, the timebox, the forbidden actions and the report shape. The done condition is your rubric, because the reviewer grades the note against it. Compare the branch and base with the brief you were started with. If they differ, or a field you need is empty, ask with `sous task ask "$SOUS_TASK_ID" "<question>"` and wait for the answer in `sous inbox`.
2. **Stay in the task's worktree.** Work in `.worker.worktree` from `sous task show`. Run `git branch --show-current` and check it prints the brief's branch. Never write in the vault's main checkout.
3. **Read the vault's rules.** Read the repo's `AGENTS.md` or `README.md` when it has one, and its templates folder. Find the nearest existing note of the same kind, such as another topic note, report or study set, and copy its folder, file name style, frontmatter keys, heading levels, tags and link style (`[[wikilinks]]` or Markdown links). Do not invent a new layout.
4. **Plan the note before you write.** Name the file path, the title and the sections that answer each part of the done condition. Keep every path inside the brief's `scope.write` and outside `scope.deny`. When the note needs a path outside the scope, such as a link added to an index note, or a choice the brief does not settle, such as the audience or the depth, ask with `sous task ask` and do not decide it yourself.
5. **Gather sources.** Read the documents, code, pages or notes the brief names, and keep where each fact came from: a URL, a page or section of a document, a `file:line`, or a command and its output. For study material, check every answer against a source, not your memory.
6. **Write the note.** Put the main point first, then the detail. Give each claim its source inline or in a `## Sources` section, and mark anything you inferred as inferred. Link only to notes that exist. Put attachments where the nearest note keeps them, inside the scope. Copy no secret, token, password, account number or private contact detail from a source into the note.
7. **Record progress.** At each real decision or finished section, run `sous task note "$SOUS_TASK_ID" "<one line>"`. A relaunched worker and the reviewer read these notes.
8. **Verify the note.** Run every command in the brief's `verify` list from the worktree root, exactly as written, and the checks under "Verify commands" below. Then read the note against each numbered check of the done condition. When a check cannot run, say so in the report and do not count it as a pass.
9. **Commit.** Run `git branch --show-current` again and stop if it is not the brief's branch. Stage only your note and its attachments, and commit with a conventional message in the repo's style, such as `docs(notes): add postgres mvcc note`. Commits carry no agent name, no task ID and no `Co-Authored-By` line. This is the last change you make to the repo: do not push and do not open a PR.
10. **File the ready report.** Answer each numbered check of the done condition with `--checks`, where a command check shows the command and its real output and a review check names the file and line:

    ```sh
    sous task report "$SOUS_TASK_ID" --status ready --head "$(git rev-parse HEAD)" \
      --summary "<the note's path and what it covers>" \
      --evidence "<each verify command with its exit code and output>" \
      --checks @"${TMPDIR:-/tmp}/sous-$SOUS_TASK_ID-checks.json"
    ```

11. **Stop.** Do not push, open a PR, merge or remove the worktree. Your machine mate runs `sous task push`, and the engine lands the work after review. A reviewer's issues come back to your inbox until the review ends.

### Timebox

The brief's `timebox` is a hard stop. When it runs out, or your inbox says "timebox reached, report what you have", commit what is finished and file `--status partial` with the head SHA, what is done, what is left and the evidence so far. Do not push. When the doorbell `[sous] inbox` arrives, read it with `sous inbox --agent "task-$SOUS_TASK_ID"` and acknowledge the events you handled with `--ack <seq>`.

## Done when

All of these hold, and anyone can check them:

- `sous task show "$SOUS_TASK_ID" | jq -r .state` prints `ready` or a later state (`reviewing`, `landing`, `landed`, `waiting`).
- `.report.head` equals `git rev-parse HEAD` in the worktree, and `git status --short` is empty.
- `git diff --name-only "<base>...HEAD"` lists only paths inside `scope.write`, none inside `scope.deny`, and no `fleet.toml`.
- Every link in the note resolves to a file in the vault, and every claim names a source or is marked inferred.
- `.report.checks` answers every numbered check of the done condition, each with a source.

## Verify commands

Run these from the worktree root. `<base>`, `<branch>` and `<note>` come from the brief and your plan.

```sh
sous task show "$SOUS_TASK_ID" | jq '.brief.verify[]'    # the brief's verify list; run each one as written
git branch --show-current                                  # the brief's branch
git status --short                                         # empty: everything is committed
git diff --name-only "<base>...HEAD"                       # every path is in scope
git log --format='%h %s%n%b' "<base>..HEAD"                # conventional subject, no agent name or task ID
grep -o '\[\[[^]|#]*' "<note>" | sed 's/^\[\[//' | sort -u # each wikilink target; find it with: git ls-files | grep -F "<target>.md"
sous task show "$SOUS_TASK_ID" | jq '{state, report}'
```

## Known pitfalls

- **Pushing or opening a PR.** You hold no GitHub credential, and the push belongs to your machine mate. The `opening-a-pr` runbook is not part of this one. Never run `git push`, `gh pr create` or `gh pr merge`.
- **Using `writing-a-report` for a ship task.** A report runbook keeps the project unchanged. A knowledge ship task changes the vault, so it ends at a commit and a report with `--head`.
- **Touching other notes.** A backlink from an index or a fixed typo in another note is outside the scope unless the brief lists that path. Propose it in the report summary as a follow-up.
- **Editing the vault's app state.** Never commit `.obsidian/workspace*.json` or other editor state that changed while you worked.
- **Claims from memory.** A note the owner studies from must be right. A claim with no source is a guess, so label it as one or leave it out.
- **Private data in the note.** Sources can hold names, addresses, account numbers or keys. Summarise what the brief needs, and never paste a secret into the vault.
- **Ending the turn without a report.** While the task is open, the Stop hook blocks your turn from ending, and after three blocks the engine marks the task stale. File a report, even `partial` or `blocked`, before you stop.
- **Installing tools.** Never install a tool, a plugin or a dependency to render or check the note. When a tool is missing, ask your machine mate with `sous task ask`.
