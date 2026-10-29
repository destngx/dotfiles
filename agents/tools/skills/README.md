# Skill evals and telemetry

The tooling in this directory works the same way for every skill, in any repo that has skills. It lives in the dotfiles repo, and home-manager links `dotfiles/agents` to `~/.agents`, so every repo calls it as `~/.agents/tools/skills/<script>`. Each script works on the git repo of the current directory, or on `--root <dir>`.

`lib.sh` picks one of two layouts:

| Repo         | Skills                  | Claude Code links                                       |
| ------------ | ----------------------- | ------------------------------------------------------- |
| project repo | `.agents/skills/<name>` | `.claude/skills/<name>` -> `../../.agents/skills/<name>` |
| dotfiles     | `agents/skills/<name>`  | `claude/skills/<name>` -> `../../agents/skills/<name>`   |

The dotfiles skills are global: `~/.agents/skills` serves other agents, and `claude/skills` is in the Claude config dir. A skill gets the tooling by adding two JSON files:

- **Evals** run `claude plugin eval` on prompts that should and should not invoke the skill, and on behaviour cases in a sandbox repo. Run them after you change a skill's description, SKILL.md or script.
- **Telemetry** comes from project hooks that log every real use of a skill to a file outside the repo. `report.sh` shows where a skill missed a prompt, fired without one, failed a step, or where the agent ran a step by hand.
- **`check.sh`** is a static check with no Claude runs. The monorepo's lint-staged runs it on every commit that touches a skill.

## 1. Add a skill

```sh
bash ~/.agents/tools/skills/new.sh tidy-up "Tidy the repo. Use when the user asks to tidy up."
```

`new.sh` creates whichever of these files are missing and never overwrites one:

```text
.agents/skills/tidy-up/
  SKILL.md               new skills only, from the description argument
  telemetry.json         what the live telemetry tracks
  evals/triggers.json    prompts the evals send
  evals/behavior/<case>/ optional, hand-written
.claude/skills/tidy-up -> ../../.agents/skills/tidy-up
```

Fill in the two JSON files until `bash ~/.agents/tools/skills/check.sh` passes, then run the evals. Running `new.sh` on an existing skill adds only the missing files.

### evals/triggers.json

```json
{
  "fire": [{ "name": "bare-merge", "context": "The feat/x work is finished in its worktree.", "prompt": "merge" }],
  "no_fire": [{ "name": "merge-two-pages", "prompt": "Merge the settings and profile pages into one." }]
}
```

Use at least 3 of each. Write `prompt` in the words you really type. Your history is the best source, and the rebase-merge list came from it. `context` is optional. It stands in for the earlier turns (the eval sends `context`, a blank line, then `prompt`), while telemetry and `check.sh` look only at `prompt`. Put close prompts that must not invoke the skill in `no_fire`.

### telemetry.json

```json
{
  "phrases": ["regexes that match every fire prompt and no no_fire prompt"],
  "script": "scripts/<script>.sh",
  "steps": ["first", "...", "last"],
  "manual": ["regexes for commands the script runs, which the agent must not run by hand"]
}
```

- **Regex syntax.** The regexes are case-insensitive and use jq's `test()` syntax (Oniguruma). Look-behind does not work with the case-insensitive flag.
- **Keep the phrases in sync.** `check.sh` fails when a fire prompt matches no phrase, or a no_fire prompt matches one, because the report would then miscount triggers.
- **Mark the finishing step.** `steps` must end with the step that finishes the job. The report counts a session as complete when that step exits 0.
- **Keep manual patterns inside the command.** `manual` patterns must not use `.*` or `.+`, so that the eval grader built from them cannot match past the end of a command.
- **Skills without a script.** Leave out `script`, `steps` and `manual`. A skill without a `telemetry.json` still has its invocations counted.

## 2. Run the evals

```sh
bash ~/.agents/tools/skills/eval.sh rebase-merge            # every case: 3 runs per trigger case, 2 per behaviour case
bash ~/.agents/tools/skills/eval.sh --all --runs 1          # every skill that has evals
bash ~/.agents/tools/skills/eval.sh rebase-merge --tag trigger --runs 1
bash ~/.agents/tools/skills/eval.sh rebase-merge --case behavior-conflict -- --keep-temp
bash ~/.agents/tools/skills/eval.sh rebase-merge --stage-only   # build the suite, print its path, run nothing
```

In the monorepo, `pnpm exec nx run skills:eval -- rebase-merge` does the same, as do the `skills:check`, `skills:report` and `skills:test` targets.

Each run starts from an empty Claude config, so your user skills (the dotfiles ones included) are not loaded. The without arm of a global skill is a real baseline.

`eval.sh` copies the skill to `tmp/skill-evals/<skill>/<timestamp>/stage/` and builds the suite there, so the repo holds no generated files:

- Each `triggers.json` entry becomes a case, graded on whether the model calls the skill.
- Each `evals/behavior/<case>/` gets two shared graders. One checks that the skill fired. The other comes from `telemetry.json` `manual` and checks that no script-owned command ran by hand.
- `sandbox.sh` is copied to `evals/_lib/sandbox.sh`.

Each run is a full Claude session on your own credential. One run of the 22 rebase-merge cases costs about $6. The results and `report.html` go next to the stage. The scores also go to the eval history, which `report.sh` shows. Arguments after `--` go to `claude plugin eval` unchanged. With `--keep-temp`, each run's sandbox and `trace.jsonl` are kept, so you can read the agent's commands when a grader fails.

Every case runs twice, once with the skill loaded and once without it. The table shows both scores and the difference (Δ).

### Behaviour cases

A behaviour case is a directory with `prompt.md`, `case.yaml` (naming `scaffold_script: scaffold.sh`), `scaffold.sh` and `graders/*.md`. The grader types are `tool_used`, `tool_order`, `regex` and `llm`. See the [plugin eval docs](https://code.claude.com/docs/en/plugin-evals.md). The scaffold builds the run's workspace with the shared library:

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../_lib/sandbox.sh"
sandbox_repo                                     # origin.git, primary/ on main with the skill installed, wt/ on feat/x
sandbox_advance_main feature.txt "v2 from main"  # optional: move main so the branch is behind
```

The rebase-merge cases (happy path, rebase conflict, dirty worktree) are working examples. When a real session goes wrong, add its prompt as a case first and keep the case once the skill is fixed.

The eval sandbox on macOS has two quirks:

- `/usr/bin/git` is an xcrun shim that the sandbox breaks, and the sandbox cannot read `Xcode.app`. `sandbox.sh` copies the real git into `$HOME/.nix-profile/bin` of the run's temp home, which is first on the agent's PATH.
- The sandbox blocks writes to `.git/config`, so `git push -u` cannot record the upstream. The push itself works, and the agent usually mentions the warning in its report.

## 3. Telemetry

A project's `.claude/settings.json` (the monorepo's does) runs `~/.agents/tools/skills/hook.sh` asynchronously on these events:

| Event                                 | What it logs                                                                                    |
| ------------------------------------- | ----------------------------------------------------------------------------------------------- |
| UserPromptSubmit                      | a prompt that matches one of a skill's trigger phrases (first 160 characters)                   |
| PreToolUse on Skill                   | a model-initiated skill call, with its args                                                     |
| PostToolUse, PostToolUseFailure, Bash | a run of a skill's script, with the subcommand, exit code and `key=value` output                |
| PreToolUse on Bash                    | a command that matches a skill's `manual` patterns, run within 3 hours of the model invoking it |

The hook logs only the skills of the project it runs in, so the dotfiles skills have no live telemetry. Their `telemetry.json` keeps `check.sh` and the evals in agreement. The hook writes nothing for other prompts or commands. The log is `<git common dir>/skill-telemetry/events.jsonl` (in this checkout, `.git/skill-telemetry/`). Every worktree writes to the same file, and git never tracks it. Hook errors go to `hook-errors.log` in the same directory, and the hook always exits 0.

```sh
bash ~/.agents/tools/skills/report.sh                    # every skill, all time
bash ~/.agents/tools/skills/report.sh --skill rebase-merge --since 2026-10-01
bash ~/.agents/tools/skills/report.sh --json             # the same data for scripts
```

For each skill, the report shows:

- how many times the model invoked it
- **possible misses**: prompts that matched a trigger phrase where the model did not call the skill within 10 minutes
- **unprompted calls**: model calls with no trigger phrase before them, which is either over-triggering or a phrase missing from `telemetry.json`
- for a skill with a script, each session's step sequence with exit codes (`prepare:0 land:0 cleanup:0`), how many sessions reached the last step with exit 0, and the commands run by hand that the script owns
- the last 5 eval runs
- a note when the skill has no `telemetry.json` or no `evals/triggers.json`

### Act on the report

| Report says                                   | Change                                                                                 |
| --------------------------------------------- | -------------------------------------------------------------------------------------- |
| possible miss on a prompt that should fire    | add the wording to the SKILL.md `description`, and add it to `triggers.json` `fire`    |
| a miss that was right not to fire             | narrow the phrase in `telemetry.json`, and add the prompt to `triggers.json` `no_fire` |
| unprompted call that should not have happened | narrow the `description`, and add the prompt to `triggers.json` `no_fire`              |
| unprompted call that was right                | add a phrase for the wording to `telemetry.json`, and add the prompt to `fire`         |
| a step keeps exiting non-zero                 | read the exit code in the script header, then fix the script or the step's guidance    |
| manual commands                               | make the SKILL.md step clearer, or move the command into the script                    |

Then run `check.sh` and the evals again.

## 4. Test the tooling

```sh
for t in ~/.agents/tools/skills/*.test.sh; do bash "$t"; done   # this tooling
pnpm exec nx run skills:test                                    # the monorepo's .agents/skills/*/scripts/*.test.sh
```
