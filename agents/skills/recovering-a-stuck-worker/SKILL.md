---
name: recovering-a-stuck-worker
description: Recover a sous worker that is stale, looping, silent or asking what its brief already answers, as the first mate or a machine mate. Read the task state, answer or redirect with sous task note, restart the worker with sous restart only when it is wedged, and stop after the second failed relaunch. Use for inbox events about a stale task, or prompts like "t-20261103-4k7q2m has been stale for 20 minutes" or "the herdr-glance worker keeps asking which branch to use". Not for a mate or engine that restarted (resuming-after-a-restart) and not for a worker that reported blocked on a decision (decisions-and-the-digest).
---

<!-- Adapted from the stuck-crewmate-recovery skill in firstmate, https://github.com/kunchenguid/firstmate, MIT License, Copyright (c) 2026 Kun Chen. -->

# recovering-a-stuck-worker

The first mate or a machine mate brings a stuck worker back to work, or stops trying and tells the owner. It reads the task's state first, then climbs a ladder: answer, redirect, restart, give up. Each rung is one `sous` command. The mate never types into a worker's pane, never starts a second worker on the same task, and never removes a worktree.

Use only these commands: `sous task ls`, `sous task show`, `sous task note`, `sous inbox`, `sous restart`, `sous status`.

## When to use it

Use it when the inbox has an event about a stale task, when a worker ended its turn with no report, or when a worker is looping, silent, repeating the same obstacle or asking a question its brief already answers. A mate or engine that restarted goes to `resuming-after-a-restart`. A worker that reported `blocked` with a question for the owner goes to `decisions-and-the-digest`.

## Steps

1. **Read the current state.** Run:

   ```sh
   sous task show <id> | jq '{state, updated, worker, report, notes, decision}'
   sous inbox
   ```

   Read the inbox events for this task in order. The worker fields that matter are `busy`, `seen`, `started`, `nudged`, `timebox_rung`, `launches`, `blocks` and `failures`.
2. **Rule out the cases that are not stuck.** Stop here and do nothing when any of these hold:
   - The state is `ready`, `reviewing`, `landing`, `landed` or `cancelled`. The work is finished.
   - The state is `waiting`, or the task is `blocked` with a decision. It waits on the owner, which `decisions-and-the-digest` handles.
   - The worker is busy and the timebox has not run out. A long turn is allowed. An unknown busy state counts as busy, never as idle.
   - The worker's context is low. Claude compacts and goes on, so that is no reason to restart it.
3. **Answer from the brief.** When the worker is waiting on a question its brief answers, run `sous task note <id> "<the answer in one line, quoting the brief field>"`. For example, `sous task note t-20261103-4k7q2m "brief.branch is feat/task-list and brief.base is main. Use those."` Sous delivers the note to the worker's inbox and rings its doorbell.
4. **Redirect a confused or looping worker.** Send one corrective note that names the next action, such as `sous task note <id> "Stop retrying the flaky e2e test. It is outside your scope. Run the unit tests in brief.verify, then file your report."` Check again after one heartbeat (10 minutes) with `sous task show <id> | jq '.worker.seen, .notes[-3:]'`.
5. **Restart a wedged worker.** A worker is wedged when it is looping after a redirect, does not respond, hits the same obstacle again, or its pane has no agent. First record the progress so the new session starts from it, then restart it:

   ```sh
   sous task note <id> "progress before restart: <what is done, what is next>"
   sous restart task-<id>
   ```

   Sous asks the worker to save its open work, waits up to 5 minutes for it to go idle, then starts a new session in the same worktree with the same task ID, the brief, the notes and a new token. The branch, commits and uncommitted files stay. Check it with `sous task show <id> | jq '.state, .worker.launches, .worker.seen'`: the state is `running`, `launches` went up by one, and `seen` is recent.
6. **Stop after the second failed restart.** When the worker is still stuck after two restarts in this recovery, do not restart it again. Record the failure with `sous task note <id> "recovery failed after 2 restarts: <what happened>"`. The first mate then tells the owner in one message: what failed, what is kept (the branch, the commits and the worktree path from `.worker.worktree`), what it means for the goal, and the options, such as cancel, restart with a narrower brief, or leave it for the owner to look at. Follow `decisions-and-the-digest` for that message and for quiet hours. A machine mate leaves the note and the first mate picks it up.

### A stuck machine mate

The first mate restarts a machine mate with `sous restart mate-<machine>` only when `sous status` shows the mate is not alive. The engine allows 3 relaunches of a mate per hour. After that it raises one alarm and stops relaunching until the owner acts. Do not try again past the alarm. Tell the owner instead.

## Done when

One of these holds, and `sous task show <id>` shows it:

- The worker is moving again: `.worker.seen` changed after your note or restart, or a new note or report arrived.
- The worker filed a report, and `.state` is `ready`, `partial` or `blocked`.
- After two failed restarts, the last note records the failure, and the owner has the message from step 6.

## Verify commands

```sh
sous status
sous task show <id> | jq '{state, worker: {busy: .worker.busy, seen: .worker.seen, launches: .worker.launches, blocks: .worker.blocks}}'
sous task show <id> | jq '.notes[-5:]'
sous inbox
```

## Known pitfalls

- **Restarting a finished worker.** A worker whose PR is open and whose report is filed is done, even when its pane is idle. Restarting it wastes a launch and can push a commit over reviewed work.
- **Believing the liveness line alone.** "Stale" means no state change for 240 seconds. Read the notes and the report before you act. The worker may be in one long test run.
- **A second worker on the same task.** Never create another worktree or task for the same work while the first worktree exists. Two copies split one task, and only one of them lands.
- **Tearing down unlanded work.** A worktree with commits or uncommitted changes stays until the owner decides, even after a failed recovery.
- **Restarting in a loop.** Each restart costs a launch, and a worker that fails twice will most likely fail a third time. Stop at two and tell the owner.
- **A long nudge.** Notes reach the worker as inbox events. One line that names the next action works. A paragraph of advice becomes a second brief.
