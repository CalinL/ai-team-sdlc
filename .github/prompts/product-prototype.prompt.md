---
description: 'Build and verify a clickable prototype from approved design direction using the ait-product-prototype skill.'
agent: ait-product-designer
---

# Product prototype

Apply the `ait-product-prototype` skill and route the work to the `ait-product-designer` agent persona.

Use this command when approved design direction (UX flows, wireframes, design tokens) exists and you
need a **runnable, clickable prototype** to validate the experience before technical specification.
The prototype is a throwaway spike — production UI is built later by `/product-implement`.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it as
the design direction / UX flows / design tokens to prototype.

The skill scaffolds the prototype (`web-artifacts-builder`), applies craft (`frontend-design`,
`theme-factory`), and verifies it in a real browser (`ait-prototype-testing` via the Playwright MCP)
before the `prototype-review` gate.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
prototyping logic here.

Follow `AGENTS.md` and `.github\instructions\ai-sdlc.instructions.md`, including the shared
handoff contract and any applicable tracking conventions.

Return the skill's concise result summary and next recommended phase.
