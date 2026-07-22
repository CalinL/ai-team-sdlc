---
description: 'Shape a product idea into UX flows and design direction using the ait-product-design skill (ideation stage).'
agent: ait-product-designer
---

# Product design

Apply the `ait-product-design` skill and route the work to the `ait-product-designer` agent persona.

Use this command for the **ideation** stage: explore a product idea, map user journeys, shape UX
flows and wireframes, and produce design direction and design tokens before prototyping and
technical specification. To build a runnable clickable prototype from this direction, use
`/product-prototype` next.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it as the product
idea, PRD excerpt, screen description, or feature brief to design.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
design logic here.

Follow `AGENTS.md` and `.github\instructions\ai-sdlc.instructions.md`, including the shared
handoff contract and any applicable tracking conventions.

Return the skill's concise result summary and next recommended phase.
