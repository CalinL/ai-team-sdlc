---
description: 'Turn approved product direction into technical specs using the ait-tech-specs skill.'
agent: ait-architect
---

# Product specs

Apply the `ait-tech-specs` skill and route the work to the `ait-product-owner` and `ait-architect` agent
personas: the **Product Owner** first turns the input into a PRD (requirements + acceptance
criteria), then the **Architect** turns that PRD into architecture, API contracts, and data
models. Both stages are gated by `spec-review`. If a PRD already exists, skip straight to the
architecture step.

Use this command when the user has a validated prototype, product idea, PRD, or design direction and
needs product requirements and/or technical specifications, acceptance criteria, or architectural
decisions. In the pipeline this follows `/product-prototype` (for UI work) or starts the plan
directly (for non‑UI work with no design/prototype stage).

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it as the source
material to specify.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
specification or architecture logic here.

Follow the `ait-conventions` skill, including task schema,
decision tracking, and quality-gate expectations.

Return the skill's concise result summary and next recommended phase.
