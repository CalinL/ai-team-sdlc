---
description: 'Validate acceptance criteria using the ait-qa-validation skill.'
agent: ait-qa-test
---

# Product QA

Apply the `ait-qa-validation` skill and route the work to the `ait-qa-test` agent persona.

Use this command when the user wants QA validation, acceptance testing, or test evidence for an
implemented task or feature slice.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it as the feature,
acceptance criteria, test scope, and relevant tracking paths.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
QA logic here.

Follow `AGENTS.md` and `.github\instructions\ai-sdlc.instructions.md`, including the gate order
and handoff contract.

Return acceptance results, gates run, any blockers, and next recommended phase.
