---
name: investigating-an-alert
description: Investigate an alert that a monitor such as dev-cpu-watch raised as a sous task. Confirm the alert is still real, find the cause with read-only checks, and file a report with a recommended fix, without stopping processes or changing code. Use when a sous brief comes from an alert source rather than the owner, such as "alert from dev-cpu-watch, node at 380% CPU for 10 minutes" or "disk-watch says ezmacmini is 96% full". Not for a question the owner asked (writing-a-report) and not for applying the fix, which is a separate ship task.
---

<!-- Adapted from the scout-completion and diagnostic-reasoning skills in firstmate, https://github.com/kunchenguid/firstmate, MIT License, Copyright (c) 2026 Kun Chen. -->

# investigating-an-alert

A monitor, such as `dev-cpu-watch`, raises an alert with `sous task add --source <tool> --key <fingerprint>`. Sous turns every alert into an investigate task. A sous worker finds out whether the alert is real and what caused it, and files a report with a recommended fix. The worker never applies the fix, not even to stop a runaway process. A fix is a separate task under the normal rules, and the owner approves it.

## When to use it

Use this runbook when `SOUS_TASK_ID` is set and `sous task show "$SOUS_TASK_ID" | jq -r .source` names a monitor rather than `owner`. A question the owner asked goes to `writing-a-report`.

## Steps

1. **Read the brief.** Run `sous task show "$SOUS_TASK_ID" | jq '{source, key, machine, created, brief}'`. The `source` is the monitor, the `key` is the alert's fingerprint, and `.brief.context` holds what the monitor saw, such as the process, the reading and the time. Write down the alert time and what crossed which threshold. If the context is empty, file `sous task report "$SOUS_TASK_ID" --status blocked --summary "the alert carries no reading"` and stop.
2. **Check whether it is still happening.** Run the read-only check that matches the alert, and note the time you ran it:

   | Alert | Read-only checks |
   | --- | --- |
   | CPU | `ps -Ao pid,ppid,user,pcpu,pmem,etime,command -r \| head -15`, `top -l 2 -o cpu -n 10 -stats pid,command,cpu,time` |
   | Memory | `memory_pressure`, `vm_stat`, `ps -Ao pid,rss,command -m \| head -15` |
   | Disk | `df -h`, `du -xhd 1 <mount or folder> 2>/dev/null \| sort -h \| tail -15` |
   | A service or port | `lsof -nP -iTCP -sTCP:LISTEN`, `launchctl list \| grep <label>`, the service's own log |

3. **Find what owns it.** For a process, read its parent chain with `ps -o pid,ppid,lstart,command -p <pid>`, its working folder with `lsof -a -p <pid> -d cwd`, and its open files with `lsof -p <pid> | head -40`. Map it to a project under `~/projects`, a launchd job or a sous worker. `sous task ls --state running` lists the running tasks, and `sous task show <id> | jq .worker` names each worker's worktree.
4. **Find the cause.** Keep three facts apart:
   - the trigger, the event that started it, such as a watch loop, a build or a cron job
   - the masking condition, the state that makes it happen now and not always, such as a large cache, a sleep and wake or a second copy of the same job
   - the symptom, the reading the monitor saw

   Compare with a time it was healthy. Look for an earlier alert with the same source in `sous task ls --all`, and read the project's recent history with `git -C <repo> log --since "<alert time minus 2 days>" --oneline`. Name what would prove your explanation wrong, and check it.
5. **Do not act on it.** Do not kill or renice a process, restart a service, delete files, clear a cache or change code, even when the fix is obvious. Those are fixes, and some cannot be undone.
6. **Record progress.** At each finding, run `sous task note "$SOUS_TASK_ID" "<one line>"`.
7. **Write the report** to `report="${TMPDIR:-/tmp}/sous-$SOUS_TASK_ID-report.md"` with these sections:
   - `## Alert` names the source, the reading, the threshold and the time.
   - `## Still happening` says yes or no, with the check, its time and its output.
   - `## Cause` names the trigger, the masking condition and the symptom, each marked as observed or inferred.
   - `## Evidence` holds the exact commands and the output that matters.
   - `## Recommended fix` is a draft brief for a separate task: the goal, the repo or machine, the done condition and the verify commands. When the alert was noise, recommend the monitor change instead, such as a threshold or an excluded process.
   - `## Decisions for the owner` lists each question with what it is, why it matters now, the real options and your recommendation with a one-line reason. Write `None.` when there are none.

   Use the `unslop` skill on the report.
8. **File the report.**

   ```sh
   sous task report "$SOUS_TASK_ID" --status ready \
     --summary "<the alert, whether it is still happening, the cause, the recommended fix, in two or three sentences>" \
     --evidence "$(cat "$report")"
   ```

   Use `ready` when you found the cause, or showed that the alert was noise. Use `partial` when the timebox ran out or the cause is still open. Use `blocked` when you could not read what you needed, such as another user's process.
9. **Stop.** Do not start the fix or create a task.

### Timebox

When the brief's timebox runs out, or your inbox says "timebox reached, report what you have", file what you have as `partial`. When the doorbell `[sous] inbox` arrives, read it with `sous inbox --agent "task-$SOUS_TASK_ID"` and acknowledge the events you handled with `--ack <seq>`.

## Done when

- `sous task show "$SOUS_TASK_ID" | jq -r .state` prints `ready`, `partial` or `blocked`.
- `.report.evidence` has all six sections, `## Still happening` has a timed check, and `## Decisions for the owner` lists a decision or says `None.`
- The process, service or files the alert named are in the same state as before the task, apart from changes the report shows were not yours.

## Verify commands

```sh
sous task show "$SOUS_TASK_ID" | jq '{source, key, brief: .brief.context}'
sous task show "$SOUS_TASK_ID" | jq '.brief.verify[]'   # run each one as written
grep -c '^## ' "$report"                                # 6
sous task show "$SOUS_TASK_ID" | jq '{state, report}'
```

## Known pitfalls

- **Fixing it because it is easy.** Stopping a process can kill another session's work or lose unsaved state. The report recommends, and the owner decides.
- **Reporting a reading as a cause.** "node used 380% CPU" is the symptom. Name what the node process was doing and why it started.
- **Trusting a cleared alert.** An alert that is gone when you look may come back. Say what you checked, when, and what would bring it back.
- **Blaming a sous worker without proof.** A worker's build can cause load, but match the process to its worktree before you say so.
- **Ending the turn without a report.** The Stop hook blocks your turn while the task is open, and after three blocks the engine marks the task stale.
