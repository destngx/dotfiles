---
name: decisions-and-the-digest
description: Bring decisions to the owner and record the answers, as the first mate. Send one decision per message with why it is needed now, the real options and a recommendation, hold non-urgent ones for the morning digest during quiet hours (23:00 to 07:00), and record each answer with sous decide and the owner's exact words. Use when a task waits on the owner, for inbox events about a decision, or for prompts like "what needs my call?", "morning digest" or "approve the merge for t-20261103-4k7q2m". Not for a stuck worker (recovering-a-stuck-worker) and not for resuming after a restart (resuming-after-a-restart).
---

<!-- Adapted from the decision-hold-lifecycle skill and the captain-hold-lifecycle skill it points to in firstmate, https://github.com/kunchenguid/firstmate, MIT License, Copyright (c) 2026 Kun Chen. -->

# decisions-and-the-digest

The owner reads few messages, often on a phone, so each one must be answerable with one tap. The first mate brings each open decision to the owner as its own message, holds the ones that can wait for the morning digest, and records each answer with the owner's exact words. A decision lives on its task record in sous, so it survives when the worker finishes, its worktree goes, or later events bury it.

Use only these commands: `sous task ls`, `sous task show`, `sous task note`, `sous task steer`, `sous task cancel`, `sous inbox`, `sous decide`, `sous digest`, `sous owner mark`, `sous away`, `sous status`.

`sous decide`, `sous task steer`, `sous task cancel`, `sous owner mark` and `sous away` are the sous mate's alone. The engine refuses them from any other agent, and it refuses `sous decide ID later` from a machine mate too.

## When to use it

Use it when a task waits on the owner (`waiting`, or `blocked` with a decision), when an inbox event names a decision, when the owner asks what needs them, and at the morning digest. Machine mates do not talk to the owner. A machine mate leaves a note on the task, and the first mate brings it to the owner.

## When the owner writes

Run `sous owner mark` on every message the owner writes in your pane, before you answer. It stores the time, ends away mode, and prints `previous`, `since`, `catch_up`, `reason` and `away_cleared`. Do not mark an `owner-note` event from your inbox, because it is not a message in your pane and it does not end away mode.

When `catch_up` is `true` (the `reason` is `first`, `away`, `gap` for 2 hours or more since the last mark, or `quiet-hours`), recap before you answer, even when the message asks for something else:

1. Run `sous digest --since <since from the mark>`. It reads records only.
2. Give one short recap. Start with the Attention list when the owner was away. Then say what landed (with the full PR URL), what runs, what is held for later and what waits on them.
3. Walk the waiting decisions one per message, in the digest's order: urgent first, then the oldest. Use step 4 below for each.
4. Handle the owner's own message last.

## Where decisions come from

- The engine parks a merge that the merge rules hold for the owner, such as a merge into `main`, and the task goes to `waiting`.
- A worker reports `blocked` on a question that belongs to the owner: a scope change, an open product choice, or anything irreversible.
- A report lists items under `## Decisions for the owner`.
- A worker that ended its turns without a report gets one reminder, and then the engine opens one decision.
- A held decision comes back. When the date of a `later` passes, the engine puts a `decision` event in your inbox. Ask again, and say it came back from "later".

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

   Mark a decision older than 24 hours as aged, as the digest does, and say so in the message. A decision that came back from "later" says that too.

   The options are the tap choices, so offer only real options from `.decision.options`. Include every URL the owner needs, such as the PR. The message must stand on its own, because the owner may see only this message.
5. **Record the answer.** When the owner picks an option, run `sous decide <id> <choice> --words "<the owner's exact words>"`. The choice must be one of the options offered. When the owner's words match none of them, ask again in one line. Do not map loose words to an option.
   - "Later" or "ask me tomorrow" is a hold, not a choice. Run `sous decide <id> later --until <date> --words "<the owner's exact words>"`. `<date>` is `2026-11-05` (07:00 that day), `"2026-11-05 09:30"`, an RFC 3339 time or a duration such as `36h`, and must be in the future. When the owner gives no date, ask for one. The engine raises the decision in your inbox on that date, and you ask again. A decision never times out to a default, and no one answers it for the owner.
   - "Check again" is not an answer either. Read the task, record what you find with `sous task note`, and send the decision again with the new facts, or note it as moot as in step 2.
   - When the answer changes what a worker must build, the engine passes it on. Do not edit the brief.
6. **Confirm it took.** Run `sous task show <id> | jq '{state, decision}'`. The state has moved on from `waiting` or `blocked`, for example to `landing` after a merge approval.

## The morning digest

At 07:00, or when the owner first writes after quiet hours, send the digest. Run `sous digest` (add `--since <time>` for another window, and `--human` for plain text). It reads records and writes nothing. The default window starts at the owner's last mark, else 24 hours ago. It lists each item once:

- **Attention.** When away mode was on, start with the Attention list: the actions taken from the away instructions and every landing made while the owner was away, each with its evidence (head, reviewer, PR) and the words relied on.
- **Open decisions.** Urgent first, then the oldest, with the aged ones marked. Each one still goes out as its own message, in the shape from step 4, after the summary.
- **Automatic decisions.** Workers on `auto` profiles decide within their brief and record each choice as a `decision:` note. List each one with its reason and how to reverse it, from `sous task show <id> | jq '.notes[] | select(.text | startswith("decision:"))'`.
- **Held for later.** Each decision held with `later`, with its date.
- **What landed.** Tasks in `landed`, with the branch and PR.
- **What failed or stalled.** Tasks in `failed`, `stale` or `partial`, with what is kept and what is left.
- **Skipped setups.** Each worker that reported a skipped `.gwf/setup`, with the command to run from that worktree, `gwf trust`.
- **Memory changes.** Each merge, rewrite or deletion the memory routine reported, with its reason and the restore command.

Keep the summary short. One line per item, grouped under these headings, with task IDs and URLs.

## Steering and cancelling

When the owner says something about a task that is already running ("use the cents column", "stop, I changed my mind"), act on it:

- Steer: `sous task steer <id> --words "<their exact words>"`. It needs a task in `queued`, `starting`, `running` or `stale`. The engine adds the words to the brief and delivers them to the worker. Do not paraphrase them.
- Cancel: `sous task cancel <id> --words "<their words>"`. The engine stops the worker, moves the task to `cancelled` and keeps the branch and the local copy. A task in `landing` cannot be cancelled. Tell the owner that the branch and the copy stay. Starting the work again is a new brief and a new Approve.

A steer that changes the goal or the done condition is a new brief. Show it for Approve instead.

## Away mode

When the owner says they are leaving and says what to do meanwhile, store their words exactly with `sous away set --words "<their words>"`. Read them back with `sous away show`. Only you read them. Never show them to a machine mate, a worker or a reviewer, and never pass them on as a rule. `sous away clear` ends away mode.

When you set them, restate your reading in plain sentences: what you will do, and what you cannot act on. This is for the owner; do not wait for a confirmation.

While they are set, answer a decision or a worker's question only when the words clearly cover it, and hold anything you are unsure of. Record the answer with `sous decide <id> <choice> --words "per your away instructions: <the owner's own words that cover it>"`. The engine refuses an answer without that marker. A `later` hold is not an answer and needs no marker.

Away words never authorise:

- an irreversible action: production changes, sending messages, spending money, deleting data, force-pushing
- a change to `fleet.toml` or `.agents/rules.md`
- a landing, unless the trust conditions hold. The engine checks them and refuses otherwise: the task is a ship task with a done condition and a verify command, the reviewer's PASS is pinned to the exact head being landed (a new commit after the PASS needs a fresh review), and the reviewer stated that every verify command passed at that head. A merge that `fleet.toml` makes wait stays a wait unless you answer it under the owner's away words, and the log then records it.

The owner's next message ends away mode, and `sous owner mark` says so with `away_cleared`. Then recap as in "When the owner writes".

## Owner notes

An `owner-note` event is something the owner typed into a shell with `sous note`. Treat it as their words, but not as an Approve of a brief and not as an answer to a decision unless it names the task. While away mode is on, the engine accepts only answers marked `per your away instructions:`. To record a note as the answer, first run `sous away clear`, then `sous decide <id> <choice> --words "<the note's words>"`. Handle the note on your next turn, and mention it in the next recap if it still stands.

## Messages to the owner

- The final message stands alone. It holds what happened, the task, the branch and the result. The owner should not need to scroll back or run a command.
- Always give the full PR URL, never `#123` or "the PR".
- Use plain words: local copy for worktree, sent to the machine mate for handoff, the helper on that Mac for machine mate, pass up to you for escalate, merged for landed, stopped responding for stale, the check passed for reviewer verdict PASS. Leave out doorbell and inbox event.
- Never paste a worker's output, logs or diffs. Say what they show in a sentence or two.
- An escalation or a decision leads with the evidence, then the consequence, then the options and your recommendation with one reason.
- When nothing happened and nothing needs the owner, send exactly this one line: `Nothing new. All quiet.`

## Done when

- `sous task ls --state waiting` lists only tasks whose decision was sent, is held for the digest, or was held with `sous decide <id> later --until <date>`.
- Every answered decision was recorded with `sous decide` and the owner's words, and `sous task show <id> | jq .state` shows the task moved on.
- No two unrelated decisions went out in one message, and nothing that is not urgent went out between 23:00 and 07:00.
- Every owner message was marked with `sous owner mark`, and a due catch-up got its recap before the answer.
- Every decision held with `later` has a date, and a held decision that came back was asked again.

## Verify commands

```sh
date +%H:%M
sous inbox
sous task ls --state waiting
sous task ls --state blocked
sous task show <id> | jq '{state, urgent, decision, notes: .notes[-3:]}'
sous digest
sous away show
```

## Known pitfalls

- **Answering for the owner.** The first mate never picks an option for a decision that belongs to the owner, even when the recommendation is obvious and the owner is asleep.
- **Closing a decision with the wrong words.** A retry with different words does not replace the first answer, and `sous decide` refuses it. Record the words once, as the owner wrote them.
- **Reading only the last event.** A decision buried under later events, or under a later `ready` on the same task, is still open. Read the task record, not the last line.
- **Bundling.** Three decisions in one message get one answer. Send them one by one.
- **"Hold" in the owner's chat.** Talk about the decision, not the mechanism. Say what is waiting and what the options do.
- **Skipping the mark.** A message that is not marked leaves away mode on and the next catch-up wrong. Mark every owner message, and no owner note.
- **Answering from vague away words.** If the words do not clearly cover the decision, hold it. Never use them for an irreversible action, and never pass them to a machine mate.
- **Using a note as an away answer.** The engine refuses it. Run `sous away clear` first.
- **Settling a held decision.** When a `later` date passes, ask again. Never pick the option or let it time out.
- **Paraphrasing a steer.** Pass the owner's exact words.
- **Merging after an approval.** `sous decide` lets the engine land the work. The first mate never runs a merge itself.
