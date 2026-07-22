---
description: 'Run or resume the full AI-SDLC lifecycle end-to-end using the orchestrator skill.'
agent: ait-sdlc-orchestrator
---

# Product run

Apply the `ait-sdlc-orchestrate` skill and route the work to the `ait-sdlc-orchestrator` agent persona.
This is the flagship full-lifecycle command.

Use this command when the user wants to take a product idea, PRD, spec file, or existing
`.copilot-tracking\<run-id>\` from kickoff through Plan → Build → Test → Sign-off → Deploy.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it as the specs
source, run-id to resume, scope limits, or pasted product idea.

Keep this prompt as a thin router: load and follow the orchestrator skill rather than
re-implementing decomposition, dispatch, tracking, or gate logic here.

Follow the `ait-conventions` skill. Create or resume the
tracking store, dispatch specialist skills, enforce `ait-quality-gates`, and pause for human sign-off
before deploy.

Report `DONE` only when every in-scope task is complete and required gates have passed.
