---
name: handover
description: Catch the user up on a freelance job from its handover material. Use when a new job arrives or more material lands - "new job", "handover", "start working with company X", "catch me up on <project>", "new materials for <project>" - to organise the files, transcribe recordings, read images and documents, and write a cited briefing with diagrams. Not for writing a handover document for someone else.
---

# handover

A job lives in `~/projects/<company>/<project>`: `raw/` holds the material as received, `sources/` the text made from it, `out/BRIEFING.md` the briefing. The CLI does the mechanical work and you write the briefing. Design: `~/projects/monorepo/docs/handover-intake/README.md`.

```sh
HI=~/projects/monorepo/apps/handover-intake/scripts/handover-intake
```

## 1. Find or create the job

- Inside a folder with a `job.toml` (or below one), use that job.
- Otherwise ask for the company and project only if the user did not name them. An unknown project is `unnamed` until the material or the user names it; then rename the folder and `project` in `job.toml`.
- Create it with `$HI init --company <company> --project <project>`. Add `--confidential` only when the user says the material is confidential or under NDA.
- Copy (never move) the files the user points at into `raw/`, keeping their names. Leave the originals where they were.

## 2. Ingest

Run `$HI ingest` in the job folder. It converts only new or changed files and prints a report:

- **Converted**: read every file it lists under `sources/`.
- **Read these yourself**: text, code and images Claude reads well; read them in `raw/`.
- **Frames to look at**: video frames at scene changes. Look at the ones that show slides, diagrams or consoles, use what they show in the briefing, cite the recording at the frame's time (`f_hhmmss.jpg`), then run `$HI clean`.
- **Failed** or **Unsupported**: tell the user which files and why. A missing `mac-ocr` or `hi-media` binary means `pnpm exec nx build mac-ocr` or `pnpm exec nx build handover-intake` in `~/projects/monorepo`. Never install anything; tools go through the dotfiles repo with the user's approval.

Transcripts are machine output. Read them whole, work out misheard names and terms from context, and list the corrections in the glossary.

### Confidential jobs

Claude Code is a cloud model, so in a confidential job you read only `sources/` and `out/`.

- Never open `raw/`, `work/` or `.mask/`, and never run `ingest --show-paths`.
- When the report says names wait for review, ask the user to open `.mask/review.toml` in their editor, set each entry to `mask = true` or `false`, and tell you when done. Then run `$HI ingest` again.
- Placeholders such as `[PERSON-2]` or `[HOST-1]` stand for real values. Use them as they are in the briefing; the web page shows the real values to the user.

## 3. Write the briefing

Write `out/BRIEFING.md` in English, whatever the language of the material, with these sections:

1. What the project is
2. People (who does what; mark guessed roles)
3. Current status
4. Your tasks and deadlines
5. Decisions already made
6. Glossary (client terms, abbreviations, transcript corrections)
7. Timeline
8. Questions for the guide

Rules:

- Cite every claim in backticks with the path under `raw/`: `` `kickoff.mp4 @ 00:14:32` `` for a moment in a recording, `` `spec.pdf p.3` `` for a page, `` `notes/plan.md` `` for a whole file. The web page turns these into links that open the file at that page or second.
- Mark anything no source states as inferred. Say plainly when the material does not cover a section.
- Add Mermaid diagrams where they explain the business: a flowchart of the system or process, a state chart of the main entity's lifecycle, a sequence diagram of the key interaction, a mind map of the project. Draw what the material shows, not a generic picture.
- When new material arrives, update the briefing in place: keep what still holds, change what moved, and add the new facts with their citations.

## 4. Commit and show

- In the job folder: `git add -A && git commit -m "<what arrived>: <what changed in the briefing>"`. The job repo has no remote; never add one.
- Start the page if it is not running: `$HI serve` in the background, then give the user `http://127.0.0.1:8765/job/<company>/<project>/`.
- Reply with a short summary of the project, the status, and the questions for the guide.
