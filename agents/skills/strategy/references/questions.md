# Question types

Each type fills a part of `STRATEGY.md`. The examples show the shape only; real questions name this project's own files, features and decisions, and follow the rules in SKILL.md ("Writing a question").

| #   | Type             | Fills                                | Ask in   |
| --- | ---------------- | ------------------------------------ | -------- |
| 1   | Purpose          | Purpose                              | Create   |
| 2   | Success          | Success                              | Create   |
| 3   | Forced trade-off | Principles and their order           | Create   |
| 4   | Scope probe      | Non-goals                            | Create   |
| 5   | Red line         | Hard rules                           | Create   |
| 6   | Past decisions   | Principles taken from the history    | Create   |
| 7   | Delegation       | What agents decide, what they ask    | Create   |
| 8   | Tie-break        | Order between principles             | Create   |
| 9   | Long-lived truth | Principles versus current choices    | Create   |
| 10  | Failure          | Hard rules                           | Create   |
| 11  | Taste            | Style principles                     | Create   |
| 12  | Drift            | Principles, non-goals or Exploring   | Review   |
| 13  | Fork             | Principles or their order            | Review   |

## 1. Purpose

Who the project is for and what it does for them. "If this project stopped working tomorrow, what would you miss first?" "Who uses it besides you?"

## 2. Success

What would show it works, ideally something that can be checked. "Six months from now, what would tell you it worked?" "What number or habit would change?"

## 3. Forced trade-off

Two things the owner wants, where a real change can only have one. Build it from a change the project could plausibly get. "This could ship in a day by skipping the review step, or in three with it. Which?" Common pairs: speed or safety, agent freedom or owner control, more features or a smaller tool, convenience or privacy, a dependency or hand-written code, local or hosted.

## 4. Scope probe

A plausible request next to the project's purpose. "Someone asks the app to also do X. In or out?" A "no" becomes a non-goal; a "yes" often needs a principle that says where the new scope stops.

## 5. Red line

What the owner would undo on sight. "Which change would you revert without discussion?" "What must an agent never do here, even when asked?"

## 6. Past decisions

Show a real decision from the records, a revert, or a memory about the project, and ask whether it is a rule or a one-off. "In March you chose to deny everything by default and allow by exception. Is that a rule for every new feature, or was it for that case?" This is the richest source for a project with a long history: it turns choices already made into principles, so the owner confirms instead of inventing.

## 7. Delegation

Which choices agents may make alone and which they must bring to the owner. "Which decisions should never be made without you?" "Which questions do you never want to be asked?"

## 8. Tie-break

Two confirmed principles that conflict in a real case. "Principle 2 says no new dependencies; principle 4 says ship the export this week, and the fast way needs a library. Which wins?" The answer sets the order of the principles.

## 9. Long-lived truth

What stays true when the code changes. "If the code were rewritten in two years, what should still be true?" Things that would not survive a rewrite are current choices; they belong in `AGENTS.md` or the docs, not here.

## 10. Failure

What happens when something cannot be checked or goes wrong. "When a check cannot run, should the tool stop or carry on?" "Should a failure be loud or quiet?"

## 11. Taste

When words do not settle it, show two real options, such as two diffs, two screens or two messages, and ask which is right and why. The why becomes the principle.

## 12. Drift (review)

Recent changes that went somewhere no principle covers. "These three changes since the last review moved the app towards X, which the strategy does not mention. Adopt X as a principle, make it a non-goal, or keep it under Exploring?"

## 13. Fork (review)

A place where the next step could go two ways. "The next work could go into A or B. The principles point to A because of principle 3. Agree, or should a new principle decide it?"
