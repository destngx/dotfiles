---
name: strategy
description: Draft and keep up a project's STRATEGY.md, its principles and non-goals, by interviewing the owner with plain questions about real scenarios. Use when the owner wants a strategy or vision for a project, or to review one - "set up the strategy for sous", "write a vision for this project", "what should go in STRATEGY.md", "review the strategy", "has the project drifted", "update the strategy". Not for a spec of one feature (REQUIREMENTS.md), not for how-to-work rules (AGENTS.md), and not for stress-testing one plan (grill-me).
---

# strategy

A project's `STRATEGY.md` lists the principles that decide which changes make sense for it, the things it will not do, and the order in which principles win when they conflict. Agents use it to decide ambiguous cases without asking, and a reviewer fails a change that breaks a principle.

The owner writes the strategy, not the agent. The agent finds the questions, suggests answers from evidence, and drafts the file from the owner's answers. Nothing goes into the file that the owner did not confirm.

## How it differs from the other files

| File              | Answers                                | Ends?                      |
| ----------------- | -------------------------------------- | -------------------------- |
| A brief or task   | what to do now                         | yes, when it is done       |
| `REQUIREMENTS.md` | what to build: the spec                | per feature                |
| `AGENTS.md`       | how to work in this repo               | changes often              |
| `STRATEGY.md`     | which changes make sense at all        | no, it is reviewed instead |

A goal can be finished. A principle is never finished; it keeps deciding.

## Where the file lives

- In the project's own repo, so every machine and every agent reads the same version.
- A monorepo keeps one per app at `docs/<app>/STRATEGY.md`, next to that app's `AGENTS.md` and `REQUIREMENTS.md`. A single-project repo keeps it at the root.
- A repo the owner does not own, such as a client's, gets no commit. Keep the file in the job folder next to the handover material.
- A public repo publishes the file on push. Keep private reasoning, names and numbers out of it.
- The project's `AGENTS.md` links it in one line near the top, so agents that read `AGENTS.md` find it: "Principles and non-goals: `STRATEGY.md`. A change that breaks one is refused, citing its number."

No agent edits a `STRATEGY.md` unless the owner approved that exact text in the same conversation. Under sous, the guard keeps workers out of the file.

## Modes

Pick the mode from the request and from whether the file exists.

- **Create.** There is no `STRATEGY.md` yet.
- **Review.** The file exists and the owner, or a scheduled routine, asks whether the project still follows it.
- **Amend.** The owner overruled a refusal, or made a decision the file does not cover, and wants the file to match.

## Create

1. **Gather evidence before asking anything.** Use sub-agents to read the repo: its README and docs, `AGENTS.md`, `REQUIREMENTS.md`, decision records, the git history (reverts and rewrites say a lot), and the owner's memory files about the project when the session has them. Finding facts is the agent's job, never the owner's.
2. **List candidate principles.** From the evidence, write down what the project already seems to hold to, each with the files or commits that suggest it. These seed the questions; they are not the answer.
3. **Ask in rounds.** Use the question types in [references/questions.md](references/questions.md). Start with purpose, success and past decisions, then trade-offs and scope probes, then tie-breaks once there are principles to rank. Ask a round of three to five questions, wait for the answers, and build the next round from them.
4. **Stop when the file can be written.** Every principle has at least one answered scenario, the non-goals are listed, and the order between principles that can conflict is settled.
5. **Draft from the template** in [references/template.md](references/template.md). Quote the owner's own words for each principle. Show the whole draft and ask for approval. Change it until the owner approves.
6. **Write and link.** Write the file, add the line to the project's `AGENTS.md`, and commit by the repo's rules. The file's "Approved" line holds the date and the owner's approving words.

## Writing a question

Owners misread clever hypotheticals, and a misread answer becomes a wrong principle. Every question must:

- name a real scenario from this project: a file, a feature, a past decision or a plausible next request
- be in plain words the owner could have said, with no riddles, metaphors or invented projects
- give a recommended answer, worded so "yes" accepts it
- say what each answer would change: what agents would then do or refuse

Format each one as:

```
**Q3 · Scope probe.** Someone asks the app to send weekly spending emails. Should that be in scope?

Recommended: no. The app shows money on screens you open; it does not push.
- Yes: agents may add email sending, and the strategy gets a principle about which messages are allowed.
- No: "sends email" becomes a non-goal, and the reviewer refuses a change that adds it.
```

Ask one round, then wait. Never answer a question for the owner, and never put a principle in the draft the owner did not confirm.

## Review

The review finds where the project and its strategy have parted. It reports; it never edits the file.

1. Read `STRATEGY.md` and the date on its last "Reviewed" or "Approved" line.
2. Read what changed since that date: landed commits, new decision records, refusals the owner overruled, and new `Exploring` items.
3. Report three lists, each item phrased as a question in the format above:
   - **Drift.** Changes that went somewhere no principle covers. "Adopt it as a principle, add it as a non-goal, or keep exploring?"
   - **Forks.** Places where the next step could reasonably go two ways, and which way the principles point.
   - **Stale principles.** Principles nothing tested since the last review, and any that the owner's recent decisions contradict.
4. When the owner answers, switch to Amend for the answers that change the file.

A change outside every principle that breaks none is not a violation. A new direction can turn out better than the plan, so the review asks about it instead of calling it wrong.

## Amend

1. Name the decision that does not match the file, with the owner's words.
2. Ask: "Is this a rule from now on, or a one-off?" A one-off changes nothing.
3. For a rule, draft the smallest edit: a new or reworded principle, a new non-goal, a changed order or an `Exploring` item. Show the diff and ask for approval.
4. On approval, edit the file, add a "Reviewed" line with the date and the owner's words, and commit by the repo's rules.
