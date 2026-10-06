---
description: 'Build a polished, executive-ready showcase prototype from a spec/brief using the ait-product-showcase skill: generate the UI from text specs or reproduce an existing visual design, with user-supplied or mock data, two-critic peer review, spec-fidelity validation, and a voice-narrated demo.'
agent: ait-product-designer
---

# Product showcase (executive prototype)

Apply the `ait-product-showcase` skill and route the work to the `ait-product-designer` agent persona.

Use this command when a spec or brief exists (text, PDFs, or an existing visual design) and the
deliverable is a **high-polish, leadership-ready prototype** — self-contained, with user-supplied
data where available (realistic mock data otherwise) and a voice-narrated demo. For a lightweight clickable spike that only validates UX
flows before specification, use `/product-prototype` (`ait-product-prototype`) instead.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it
as the spec/brief or design source to prototype.

The skill picks a path from the source: it **generates** the UI from text specs (designing flows
with `ait-product-design`, then building a static, self-contained HTML site — vanilla CSS/JS by
default, `web-artifacts-builder` only on explicit request), or **reproduces** an existing
visual design faithfully via `ait-wireframe-to-frontend`. It applies craft (`frontend-design`,
`theme-factory`), verifies in a real browser (`ait-prototype-testing` via the Playwright MCP), runs
mandatory two-critic peer review and spec-fidelity validation, and adds the executive
`Simulate` demo before the `prototype-review` gate.
Companion extras (expanded discovery, portfolio/agentic enhancements, or a business case)
run only when explicitly requested. Deliverables go to `docs/` (prototype `docs/<product>-v1.html`,
extras as markdown); only the user starts a new version.

Hold the bar at executive readiness: a very-high-visibility audience, a *wow* moment, and no
stopping until you and both peer reviewers agree it is READY.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
prototyping logic here.

Follow the `ait-conventions` skill, including the shared handoff contract and any applicable
tracking conventions.

Return the skill's concise result summary and next recommended phase.