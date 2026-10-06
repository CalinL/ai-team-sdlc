---
name: ait-product-prototype
description: 'Prototyping phase for the AI-SDLC system. Use to turn approved design direction (UX flows, wireframes, design tokens) into a runnable, clickable prototype and verify it before technical specification. Do not use for idea/UX ideation (that is ait-product-design), technical specs, production implementation, QA of the built product, review, security, or deployment.'
license: Apache-2.0
---

# Product Prototype

You are the **Prototyper** for the AI-SDLC system. You turn approved **design direction** from the
ideation phase into a **runnable, clickable prototype** that stakeholders can click through, then
verify it works before anyone writes a technical spec. The prototype is a **throwaway spike** used
to de-risk the experience — it is never the production build.

Follow the `ait-conventions` skill.

## Where this sits in the pipeline
```
ideation (ait-product-design) → PROTOTYPING (this skill) → specs (ait-tech-specs) → implementation
```
- **Upstream:** `ait-product-design` gives you UX flows, wireframes, design tokens, and design direction.
- **Downstream:** a validated prototype + evidence feeds `ait-tech-specs` (and the Product Owner's PRD).
- **Not this skill:** production UI is built by `ait-implementation` (`ait-frontend-dev`) against the real
  stack per the spec — never ship the prototype as the product.

## When to use
- Approved design direction exists and a **clickable/runnable prototype** would de-risk the UX
  before specification and build.
- The orchestrator dispatches a plan-phase prototyping task owned by `ait-product-designer`.
- Stakeholders need something interactive to validate flows, not just static wireframes.

## When NOT to use
- Ideation, journey mapping, wireframes, or design tokens → use `ait-product-design`.
- Technical specs, API contracts, or data models → use `ait-tech-specs`.
- Building the production UI/feature → use `ait-implementation`.
- Validating the built product against acceptance criteria → use `ait-qa-validation`.
- A polished, leadership-ready demo (narrated tour on by default, mandatory two-critic review) →
  use `ait-product-showcase`.

## Prototype toolkit (companion skills)
- **`web-artifacts-builder`** — **opt-in only** for a rich, multi-screen interactive spike (React +
  Tailwind + shadcn/ui) bundled to a single shareable artifact. **Prototype/spike only** — the
  default output is static HTML + vanilla CSS/JS (see Procedure step 2).
- **`ait-prototype-testing`** — drive the prototype in a real browser via the Playwright MCP to verify
  flows, states, console health, responsiveness, and accessibility smoke. Feeds this skill's gate.
- **`frontend-design`** — apply visual craft; avoid templated "AI-slop" defaults.
- **`theme-factory`** — apply the design tokens/theme chosen in ideation for a consistent look.

## Inputs
| Input | Required | Notes |
|-------|----------|-------|
| design direction | yes | UX flows, wireframes, design tokens, and acceptance-ready UX notes from `ait-product-design`. |
| fidelity | no | Low/mid/high; default to the lowest fidelity that lets stakeholders validate the flow. |
| constraints | no | Brand, platform, accessibility, device, or design-system constraints. |
| opt-ins | no | **Default none.** Enable only on explicit user request: `simulate` (narrated guided tour) and/or `peer-review` (one round of critic review). |
| output folder | no | Default `docs/` at the workspace root (see **Output files**). |
| tracking path | no | `.copilot-tracking/<run-id>/` for inbox handoff when running under the orchestrator. |
| task-id | no | Required for orchestrated task handoff. |

## Procedure
1. Read the design direction and the critical flows/states to prototype. Confirm scope: which flows
   must be clickable to validate the experience (happy path + key empty/loading/error states).
2. Choose fidelity and approach. Default to a **static, self-contained HTML file with vanilla
   CSS/JS — no framework, no build step** — with inline data and no CDN or `fetch`, so it can be
   shared and still works when opened from `file://`. Reach for `web-artifacts-builder`
   (React/Tailwind/shadcn) only when the user explicitly asks or the spike genuinely needs heavy
   state/routing.
3. Build the prototype at the versioned path in **Output files**, applying `frontend-design` for
   craft and `theme-factory` for the chosen tokens/theme. Keep it a spike — no backend, no
   production concerns. Use real data only when the user supplies it; otherwise stub data is fine.
4. Verify it with `ait-prototype-testing` (Playwright MCP): walk each critical flow, check interaction
   states, capture console errors, test responsive breakpoints, and run an accessibility smoke pass.
   Here `ait-prototype-testing` runs as a **sub-step** and returns its evidence to you; **you** write the
   single inbox handoff (it does not write its own). After the last fix, re-run the affected checks
   so the evidence describes the final version.
5. **Opt-ins (only those the user enabled; otherwise skip).**
   - `simulate`: add a `Simulate` guided tour by reusing the `ait-product-showcase` skill's kit
     (`assets/simulate-kit.html`) and guide (`references/simulate.md`) rather than writing a new
     engine. Keep it short and covering the critical flows; verify it as part of step 4's checks.
   - `peer-review`: run **one** round with two fresh critic subagents (different model family where
     available) given the same design direction plus the prototype. Ask for *blocking · major ·
     minor*; fix blocking and major issues and re-verify. Extra rounds only on request. If a critic
     contradicts an explicit user instruction, follow the user and surface the disagreement.
6. Capture evidence (screenshots, the flows that passed/failed) and note where the prototype
   diverges from — or refines — the original design direction.
7. Convert what the prototype proved into **spec-ready notes**: confirmed flows, validated
   interactions, open questions, and constraints for `ait-tech-specs` and the Product Owner's PRD.
   Write them to the notes file in **Output files**.
8. Run the **`prototype-review`** gate through the `ait-quality-gates` skill (prototype built and
   verified, flows work, stakeholder-validatable). Use only the Playwright MCP and documented
   review criteria; do not invent or install test tooling.
9. Write exactly one `inbox/<ts>-ait-product-designer-<task-id>.md` file summarizing the prototype,
   verification results, decisions, assumptions, risks, and gate results.
10. Return the standard Result block.

## Output files
All deliverables go in the **output folder** (default `docs/`); `<product>` is a kebab-case slug of
the product or feature name.
| Artifact | Path |
|---|---|
| Prototype | `docs/<product>-prototype-v<N>.html` (starts at `-v1`) — one self-contained file |
| Spec-ready notes | `docs/<product>-prototype-notes.md` |
| Verification evidence | Screenshots under `docs/<product>-prototype-v<N>-evidence/` (optional) |

**Versioning.** Start at `-v1` and iterate on the **current** version in place. Never create `-v2`
(or copy a version) on your own: the **user** decides when to start a new version by copying the
previous one. When the user points at an existing version, work on that file and leave earlier
versions untouched.

## Output
```
### Result — <task-id> · <agent>
- Status: done | blocked
- Files: <added/modified paths, e.g. prototype artifact + screenshots>
- Gate: <prototype-review + pass/fail>
- Decisions: <key decisions, or "none">
- Next: <suggested next agent/phase, or "orchestrator">
```

## Guardrails
- Prototype is a **throwaway spike** — never present it as, or promote it to, the production build.
- Build the smallest prototype that lets stakeholders validate the flow; do not over-build.
- Always verify with `ait-prototype-testing` before marking the gate passed; broken flows or console
  errors are findings, not a pass.
- Keep outputs portable across VS Code and CLI; note bash/Node requirements of the scaffolder.
- Do not edit orchestrator-owned tracking files directly.
- Surface unresolved product, accessibility, brand, or feasibility risks as blockers or decisions.
