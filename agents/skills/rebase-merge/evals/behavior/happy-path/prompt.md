---
tags: [behavior]
runs: 2
max_turns: 40
timeout_seconds: 900
allowed_tools: [Bash, Read, Glob, Grep, Skill]
---

This is a demo repo. `primary/` is the primary checkout on `main`, and branch `feat/x` is checked out in the worktree `wt/`. There is no GitHub PR and no deploy for it. The branch is reviewed and green. Merge rebase it.
