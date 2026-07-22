---
description: 'Implement planned AI-SDLC tasks using the ait-implementation skill.'
agent: ait-backend-dev
---

# Product implementation

Apply the `ait-implementation` skill. This command defaults to the `ait-backend-dev` persona; for UI /
client tasks switch to (or hand off to) `ait-frontend-dev`. Pick the persona that matches the task.

Use this command when the user wants to build an atomic task, feature slice, or implementation
work item from specs or `.copilot-tracking\<run-id>\tasks.md`.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it as the task,
acceptance criteria, scope limits, and relevant tracking paths.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
build logic here.

Follow `AGENTS.md` and `.github\instructions\ai-sdlc.instructions.md`. Specialists must write one
`inbox\` handoff file when tracking is active and run only configured gates.

Return the skill's concise result summary, files changed, gates run, and next recommended phase.
