# claude-bg-idle

Herdr plugin that shows `N bg tasks running` in the agent sidebar only while a Claude pane is idle and still has background tasks (Bash, subagents, monitors) running, so the pane is not closed by accident.

## Install

The plugin is not linked by Nix activation. Link it once per machine:

```sh
herdr plugin link ~/projects/dotfiles/herdr/plugins/claude-bg-idle
```

The link points at this directory, so edits here take effect without relinking. Remove it with `herdr plugin unlink destngx.claude-bg-idle`.

## How it works

- `claude/hooks/herdr-bg-tasks.sh` writes the running background task count to `~/.local/state/claude-herdr-bg-idle/<pane_id>` on every Claude `Stop`, and resets it to 0 on `SessionEnd`.
- `apply.sh` sets the `$bg` pane token from that count, but only when herdr reports the pane's Claude agent as `idle`; any other state clears it. It runs from the Claude hook and from herdr's `pane.agent_status_changed` event, and removes the count file on `pane.closed`.
- `herdr/config.toml` renders `$bg` as its own sidebar row; the row is hidden when the token is empty.

Known gap: killing a task from `/tasks` while Claude is idle triggers no hook, so the count stays until Claude's next turn ends.

## Debug

```sh
herdr plugin log list --plugin destngx.claude-bg-idle --limit 10
cat ~/.local/state/claude-herdr-bg-idle/*
```
