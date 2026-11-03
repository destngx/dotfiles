---
name: resuming-after-a-restart
description: Pick up the fleet when the first mate or a machine mate starts a fresh session after a crash, a planned sous restart or an engine restart. Check sous status, read and acknowledge the inbox, read every open task and its notes, and resume supervision without redoing work or relaunching workers. Also covers saving open work with sous task note when sous asks before a planned restart. Use for prompts like "you were restarted, pick up where you left off" or "the mini rebooted overnight, what is still running?". Not for one stuck worker (recovering-a-stuck-worker) and not for the owner's decisions (decisions-and-the-digest).
---

<!-- Adapted from the session-start-recovery skill in firstmate, https://github.com/kunchenguid/firstmate, MIT License, Copyright (c) 2026 Kun Chen, and from the session-pickup playbook (skills/poteto-mode/playbooks/session-pickup.md) in pstack, https://github.com/cursor/plugins/tree/main/pstack, MIT License, Copyright (c) 2026 Lauren Tan. -->

# resuming-after-a-restart

A restart loses nothing, because sous keeps every task, note, decision and inbox event on disk. When the first mate or a machine mate starts a fresh session, it rebuilds its picture of the fleet from `sous`, not from memory, and goes on from there. The engine resumes supervising the workers on its own, so the mate does not restart or redo anything just because it restarted.

Use only these commands: `sous status`, `sous inbox`, `sous task ls`, `sous task show`, `sous task note`, `sous restart`.

## When to use it

Use it at the start of a mate session that follows a crash, a planned `sous restart`, a reboot or an engine restart, and when sous asks you to save your open work before a planned restart (see the last section). A single stuck worker goes to `recovering-a-stuck-worker`.

## Steps

1. **Check the engine.** Run `sous status`. It prints the engine, the machine, the generation and the task counts by state. When it fails, the engine is down, and every other command fails too. Do not read or write `~/.local/state/sous/` yourself and do not start the engine, which launchd does. Run `sous status` again after a minute. When it still fails after five minutes, the first mate tells the owner that the engine on that machine is down. A machine mate waits.
2. **Know who you are.** `echo "$SOUS_AGENT"` prints your inbox name: `first-mate` or `mate-<machine>`.
3. **Drain the inbox in order.** Run `sous inbox`. It prints the events after your last acknowledgement, each with a `seq`, a `kind`, a task and a text. Handle each event, then acknowledge the last one you handled with `sous inbox --ack <seq>`. Never acknowledge an event before you handle it, because an acknowledged event does not come back. When you stop partway, acknowledge only up to the last event you finished.
4. **List the open tasks.** Run `sous task ls`, then `sous task ls --state <state>` for each open state: `queued`, `starting`, `running`, `partial`, `blocked`, `reviewing`, `landing`, `waiting`, `stale` and `failed`. `sous task ls` lists the tasks of the engine on your machine. In v1 every worker runs on the mini.
5. **Read each open task's record.** For each one, run `sous task show <id> | jq '{state, brief: .brief.goal, worker, report, decision, notes}'`. Read the notes from the end. A note that starts with `open work:` is something you saved before the restart, and it says what you were about to do.
6. **Sort each task by what it waits for.**
   - `queued`, `starting`, `running`, `reviewing` and `landing` wait on the engine or a worker. Leave them alone. The engine supervises them.
   - `stale` and `failed`, and a `running` task the inbox reports as stuck, go to `recovering-a-stuck-worker`.
   - `waiting`, and `blocked` with a decision, wait on the owner and go to `decisions-and-the-digest`.
   - `partial` and `blocked` without a decision need the first mate to read the report and tell the owner what is left.
7. **Pick up your saved open work.** For each `open work:` note, do the next step it names, unless the task record shows it is done already. Trust the records. Do not rerun checks or redo work that a report or a note says is finished.
8. **Tell the owner once, if anything needs them.** The first mate sends one message that names each task waiting on the owner, with its ID and what it waits for. During quiet hours (23:00 to 07:00) it holds that message for the morning digest unless a task is urgent. When nothing needs the owner, it says nothing.

## When sous asks you to save open work

Before a planned `sous restart <you>`, such as after a runbook update, sous puts an event in your inbox that asks you to record your open work, then waits up to 5 minutes for you to go idle.

1. Finish or back out of the command you are running. Start nothing new.
2. For each promise, plan or reply you hold only in this conversation, write it on its task with `sous task note <id> "open work: <what, and the next step>"`. Examples are an answer you expect from a worker, a redirect you were about to send, or a request the owner made that you have not passed on.
3. For a request from the owner that has no task yet, tell the owner in your reply what was pending, because sous keeps task state only.
4. Acknowledge the event with `sous inbox --ack <seq>` and end your turn, so you go idle and sous can restart you.

## Done when

- `sous status` answers.
- `sous inbox` prints no events after your acknowledgement.
- Every open task from `sous task ls` has been read and sorted into step 6's groups, and every task that waits on the owner is in a message or the digest queue.
- Every `open work:` note is either done or has a next step under way.

## Verify commands

```sh
sous status
echo "$SOUS_AGENT"
sous inbox                          # empty after the ack
sous task ls --state stale
sous task ls --state waiting
sous task show <id> | jq '.notes[] | select(.text | startswith("open work:"))'
```

## Known pitfalls

- **Restarting workers after your own restart.** The engine rebuilt its state and resumed supervision when it started. Only a task the engine reports as stale or stuck needs recovery.
- **Acknowledging the inbox too early.** An event acknowledged and then lost in a second crash is gone. Acknowledge after handling.
- **Redoing finished work.** The records are the source of truth. A "let me check everything from scratch" pass costs tokens and can push duplicate notes or tasks.
- **Losing open work in a planned restart.** Anything you did not write with `sous task note` is gone after the restart. Write it before you go idle.
- **Treating a sleeping machine as dead.** A task bound to the Air waits while the Air sleeps. Tell the owner which machine it waits for. Never move it to another machine.
