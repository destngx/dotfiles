---
name: decisions-and-the-digest
description: Bring decisions to the owner and record the answers, as the first mate. Send one decision per message with why it is needed now, the real options and a recommendation, hold non-urgent ones for the morning digest during quiet hours (23:00 to 07:00), and record each answer with sous decide and the owner's exact words. Use when a task waits on the owner, for inbox events about a decision, or for prompts like "what needs my call?", "morning digest" or "approve the merge for t-20261103-4k7q2m". Not for a stuck worker (recovering-a-stuck-worker) and not for resuming after a restart (resuming-after-a-restart).
---

<!-- Adapted from the decision-hold-lifecycle skill and the captain-hold-lifecycle skill it points to in firstmate, https://github.com/kunchenguid/firstmate, MIT License, Copyright (c) 2026 Kun Chen. -->

# decisions-and-the-digest

The owner reads few messages, often on a phone, so each one must be answerable with one tap. The first mate brings each open decision to the owner as its own message, holds the ones that can wait for the morning digest, and records each answer with the owner's exact words. A decision lives on its task record in sous, so it survives when the worker finishes, its worktree goes, or later events bury it.

Use only these commands: `sous task ls`, `sous task show`, `sous task note`, `sous inbox`, `sous decide`, `sous status`.

## When to use it

Use it when a task waits on the owner (`waiting`, or `blocked` with a decision), when an inbox event names a decision, when the owner asks what needs them, and at the morning digest. Machine mates do not talk to the owner. A machine mate leaves a note on the task, and the first mate brings it to the owner.

## Where decisions come from

- The engine parks a merge that the merge rules hold for the owner, such as a merge into `main`, and the task goes to `waiting`.
- A worker reports `blocked` on a question that belongs to the owner: a scope change, an open product choice, or anything irreversible.
- A report lists items under `## Decisions for the owner`.
- A worker that ended its turns without a report gets one reminder, and then the engine opens one decision.

`sous task show <id> | jq .decision` holds the open question with its `question`, `options`, `recommend`, `why` and `at`.

## Steps

1. **Find the open decisions.** Run `sous inbox`, then:

   ```sh
   sous task ls --state waiting
   sous task ls --state blocked
   sous task show <id> | jq '{state, urgent, brief: .brief.goal, decision, report: .report.summary}'
   ```

   Read every open decision, not only the newest event. A decision followed by later events is still open.
2. **Check that each one is still live.** Read the task's latest notes and report. When the facts changed, such as the worker finding the answer in the code, do not send it. Note why with `sous task note <id> "decision moot: <evidence>"`. Never close it with `sous decide`, because that records an answer the owner did not give.
3. **Check the clock.** Quiet hours run from 23:00 to 07:00 local time (`date +%H:%M`). During quiet hours, send a decision only when `.urgent` is `true`. Hold every other decision for the morning digest.
4. **Send one decision per message.** Never batch unrelated decisions into one message. Use the decision's own options and recommendation, in this shape:

   ```text
   <What it is, in one sentence, with the repo and task ID.>
   <Why it is needed now: what waits on it, and what happens if nobody answers.>

   1. <option> (recommended)
   2. <option>

   I recommend <option> because <one-line reason>.
   ```

   The options are the tap choices, so offer only real options from `.decision.options`. Include every URL the owner needs, such as the PR. The message must stand on its own, because the owner may see only this message.
5. **Record the answer.** When the owner picks an option, run `sous decide <id> <choice> --words "<the owner's exact words>"`. The choice must be one of the options offered. When the owner's words match none of them, ask again in one line. Do not map loose words to an option.
   - "Later" or "ask me tomorrow" is not a choice. Leave the decision open and record it with `sous task note <id> "owner deferred: <exact words>, ask again <date>"`. It comes back in the digest on that date.
   - "Check again" is not an answer either. Read the task, record what you find with `sous task note`, and send the decision again with the new facts, or note it as moot as in step 2.
   - When the answer changes what a worker must build, the engine passes it on. Do not edit the brief.
6. **Confirm it took.** Run `sous task show <id> | jq '{state, decision}'`. The state has moved on from `waiting` or `blocked`, for example to `landing` after a merge approval.

## The morning digest

At 07:00, or when the owner first writes after quiet hours, send the digest. It lists each item once:

- **Open decisions.** Each one still goes out as its own message, in the shape from step 4, after the summary.
- **Automatic decisions.** Workers on `auto` profiles decide within their brief and record each choice as a `decision:` note. List each one with its reason and how to reverse it, from `sous task show <id> | jq '.notes[] | select(.text | startswith("decision:"))'`.
- **What landed.** Tasks in `landed`, with the branch and PR.
- **What failed or stalled.** Tasks in `failed`, `stale` or `partial`, with what is kept and what is left.
- **Skipped setups.** Each worker that reported a skipped `.gwf/setup`, with the command to run from that worktree, `gwf trust`.
- **Memory changes.** Each merge, rewrite or deletion the memory routine reported, with its reason and the restore command.

Keep the summary short. One line per item, grouped under these headings, with task IDs and URLs.

## Done when

- `sous task ls --state waiting` lists only tasks whose decision was sent, is held for the digest, or was deferred with a note.
- Every answered decision was recorded with `sous decide` and the owner's words, and `sous task show <id> | jq .state` shows the task moved on.
- No two unrelated decisions went out in one message, and nothing that is not urgent went out between 23:00 and 07:00.

## Verify commands

```sh
date +%H:%M
sous inbox
sous task ls --state waiting
sous task ls --state blocked
sous task show <id> | jq '{state, urgent, decision, notes: .notes[-3:]}'
```

## Known pitfalls

- **Answering for the owner.** The first mate never picks an option for a decision that belongs to the owner, even when the recommendation is obvious and the owner is asleep.
- **Closing a decision with the wrong words.** A retry with different words does not replace the first answer, and `sous decide` refuses it. Record the words once, as the owner wrote them.
- **Reading only the last event.** A decision buried under later events, or under a later `ready` on the same task, is still open. Read the task record, not the last line.
- **Bundling.** Three decisions in one message get one answer. Send them one by one.
- **"Hold" in the owner's chat.** Talk about the decision, not the mechanism. Say what is waiting and what the options do.
- **Merging after an approval.** `sous decide` lets the engine land the work. The first mate never runs a merge itself.
