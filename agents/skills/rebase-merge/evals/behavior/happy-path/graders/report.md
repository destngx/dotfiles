---
type: llm
weight: 2
---

The run is a demo repo with no GitHub PR and no deploy, inside a sandbox that may block git from writing upstream
tracking to .git/config (harmless: the push still goes through).

PASS if the final message says feat/x landed on main without a merge commit, and reports all of: the new main commit
SHA (full or short), the PR state (none, unknown, or that it could not be checked), that there was no deploy to
watch, that the worktree, the local branch and the remote branch were removed, and whether the primary checkout was
pulled. Mentioning sandbox warnings is fine.
FAIL if any of these is missing, if it claims a deploy or a live-site check happened, or if it says the branch did
not land.
