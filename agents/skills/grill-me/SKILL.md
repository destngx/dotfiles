---
name: grill-me
description: Interview the user relentlessly about a plan, decision, or idea until both sides share one understanding of it, asking in rounds with a recommended answer for each question. Use when the user wants their thinking stress-tested or questioned before anything is built - "grill me", "grill this plan", "grill me on X", "stress-test my idea", "poke holes in this", "interview me about", "ask me questions until". Not for reviewing code, and not when the user only wants a plan written.
---

<!-- Adapted from the grill-me and grilling skills in https://github.com/mattpocock/skills, MIT License, Copyright (c) 2026 Matt Pocock. -->

# grill-me

Interview the user relentlessly until you reach a shared understanding. Map the subject as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled, meaning the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round. Number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Word each question so "yes" accepts your recommended answer.

Each round the user answers reshapes the tree. Settled decisions push the frontier outward and unblock the questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (files, git history, docs, tools), dispatch a sub-agent to find it. Don't ask the user for anything you could look up yourself. Don't block on it either. A running lookup is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report, and you ask the rest of the frontier now. The _decisions_ are the user's. Put each one to them and wait. Never answer a decision yourself.

If a question can only be settled by seeing something (how a screen should look or feel), say so and suggest a throwaway prototype instead of rephrasing the question.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Then summarise the decisions and ask the user to confirm you have reached a shared understanding. Do not write code, files, or plans until they confirm.
