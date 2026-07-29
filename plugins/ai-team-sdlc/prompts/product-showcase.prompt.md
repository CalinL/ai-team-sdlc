---
description: 'Build a polished, executive-ready showcase prototype from a spec/brief using the ait-product-showcase skill: generate the UI from text specs or reproduce an existing visual design, with mock data, peer or self review, spec-fidelity validation, and an optional voice-narrated demo.'
agent: ait-product-designer
---

# Product showcase (executive prototype)

Apply the `ait-product-showcase` skill and route the work to the `ait-product-designer` agent persona.

Use this command when a spec or brief exists (text, PDFs, or an existing visual design) and the
deliverable is a **high-polish, leadership-ready prototype** — self-contained, with realistic mock
data and an optional voice-narrated demo. For a lightweight clickable spike that only validates UX
flows before specification, use `/product-prototype` (`ait-product-prototype`) instead.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it
as the spec/brief or design source to prototype.

The skill picks a path from the source: it **generates** the UI from text specs (designing flows
with `ait-product-design`, then building a static, self-contained HTML site — vanilla CSS/JS by
default, `web-artifacts-builder` only on explicit request), or **reproduces** an existing
visual design faithfully via `ait-wireframe-to-frontend`. It applies craft (`frontend-design`,
`theme-factory`), verifies in a real browser (`ait-prototype-testing` via the Playwright MCP), runs
peer or structured self review and spec-fidelity validation, and adds the optional executive
`Simulate` demo before the `prototype-review` gate.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
prototyping logic here.

Follow the `ait-conventions` skill, including the shared handoff contract and any applicable
tracking conventions.

Return the skill's concise result summary and next recommended phase.