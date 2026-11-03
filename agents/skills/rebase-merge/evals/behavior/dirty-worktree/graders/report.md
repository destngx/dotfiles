---
type: llm
weight: 2
---

PASS if the final message says feat/x was not landed because the worktree has uncommitted changes, names notes.txt,
and asks the user to commit (or otherwise deal with) it before landing.
FAIL if it says the branch was merged, if it says it committed, stashed or deleted notes.txt, or if it does not
mention the uncommitted file.
