---
name: ait-prototype-testing
description: 'Prototype testing phase for the AI-SDLC system. Use in the plan/prototype stage to verify the design-phase prototype — static HTML, a clickable prototype, or a bundled web artifact — by driving it in a real browser via the Playwright MCP: checking flows, interaction states, console errors, responsive layout, and accessibility smoke. Do not use to validate the production product built from spec (that is ait-qa-validation).'
license: Apache-2.0 (adapted from Anthropic webapp-testing; see LICENSE.txt)
---

# Prototype Testing

You verify the **design-phase prototype** for the AI-SDLC system. You drive the prototype we
*designed* — a static HTML page, a clickable prototype, or a bundled `web-artifacts-builder`
artifact — in a real browser using the **Playwright MCP**, and report whether the intended UX
flows and states actually work before the idea is handed to spec and implementation.

Follow `.github/instructions/ai-sdlc.instructions.md` and `AGENTS.md`.

> **Repurposed from Anthropic's `webapp-testing` skill (Apache-2.0, see `LICENSE.txt`).**
> That skill wrote native Python Playwright scripts; this one uses the **Playwright MCP** tools
> already available in VS Code Copilot and the CLI, so no Python/Node test harness is vendored.

## Prototype testing vs. ait-qa-validation (the boundary)
| | `ait-prototype-testing` (this skill) | `ait-qa-validation` |
|---|---|---|
| **Phase** | plan (prototype stage) | test |
| **Under test** | the *prototype we designed* — static/clickable HTML or bundled artifact | the *real product built from the spec* |
| **Question** | "Does the intended UX flow work as prototyped?" | "Does the built software meet the acceptance criteria?" |
| **Owner** | `ait-product-designer` | `ait-qa-test` |
| **Feeds gate** | `prototype-review` | `acceptance` |
| **Tooling** | Playwright MCP (browser automation only) | the target repo's real unit/integration/e2e stack |

If you are validating shipped, spec-derived behavior against acceptance criteria, stop and use
`ait-qa-validation` instead.

## When to use
- A prototype exists (static HTML, clickable prototype, or a `web-artifacts-builder` bundle) and
  its UX flows, interaction states, or navigation need to be verified before spec/build.
- The `ait-product-prototype` step produced a runnable prototype and wants evidence it behaves as intended.
- The orchestrator dispatches a plan-phase prototype-verification task.

## When NOT to use
- Testing the production build against acceptance criteria → use `ait-qa-validation`.
- There is no runnable prototype yet (only flows/wireframes) → build it in `ait-product-prototype`
  (or stay in `ait-product-design` for the flows/wireframes themselves).
- Reviewing code, security, or deploying → use the matching phase skill.

## Inputs
| Input | Required | Notes |
|-------|----------|-------|
| prototype | yes | Path to static HTML, a `bundle.html` artifact, or a URL / local dev server. |
| UX intent | yes | The flows, states, and acceptance-ready UX notes from `ait-product-design` to verify against. |
| viewports | no | Target responsive breakpoints; default to a desktop + mobile pair. |
| tracking path | no | `.copilot-tracking/<run-id>/` for inbox handoff under the orchestrator. |
| task-id | no | Required for orchestrated task handoff. |

## Procedure
> **Tool naming:** the Playwright MCP tools below are shown with their base names
> (`browser_navigate`, `browser_click`, …). Depending on how the MCP server is registered in your
> host, they may be exposed namespaced (e.g. `playwright-browser_navigate`). The workflow is
> identical — use whichever prefix your environment surfaces.
1. Locate the prototype. For a static file, use a `file://` URL or serve the folder; for a bundled
   artifact, open `bundle.html`; for a dynamic app, ensure its dev server is running first.
2. Open it with the Playwright MCP: `browser_navigate`, then **wait for the page to settle**
   (network idle / expected text) before inspecting — dynamic prototypes render after load.
3. Capture ground truth: `browser_snapshot` (accessibility tree, preferred for actions) and, when a
   visual is needed, `browser_take_screenshot`. Identify selectors/refs from the snapshot.
4. Walk each **critical UX flow** from the design intent: happy path plus empty, loading, error, and
   edge states. Drive it with `browser_click`, `browser_type`, `browser_fill_form`,
   `browser_select_option`, etc., asserting the expected state appears at each step.
5. Check **responsive behavior** with `browser_resize` at the target viewports, and run an
   **accessibility smoke** pass over the snapshot (roles, names, focus order, obvious contrast/label gaps).
6. Collect **console errors** via `browser_console_messages` (level `error`) and note failed network
   requests; a broken prototype flow or console error is a finding, not a pass.
7. Record evidence (screenshots, the flows that passed/failed, console output) and map each result
   back to the UX intent so `ait-product-prototype` can close or revise the `prototype-review` gate.
8. Contribute results to the **`prototype-review`** gate via the `ait-quality-gates` skill. Use only the
   Playwright MCP and documented review criteria; do not invent or install test tooling.
9. **Handoff depends on how you were invoked:** when dispatched as a **standalone** task, write
   exactly one `inbox/<ts>-ait-product-designer-<task-id>.md` summarizing flows verified, findings,
   evidence, and gate results. When invoked as a **sub-step of `ait-product-prototype`**, do **not**
   write your own inbox file — return the evidence and gate result to the parent, which writes the
   single handoff (one handoff per specialist task, per the shared contract).
10. Return the standard Result block.

## Output
```
### Result — <task-id> · <agent>
- Status: done | blocked
- Files: <added/modified paths, e.g. screenshots, or "none">
- Gate: <prototype-review contribution + pass/fail>
- Decisions: <key findings, or "none">
- Next: <suggested next agent/phase, or "orchestrator">
```

## Guardrails
- Test only the **prototype**, never treat prototype results as production QA sign-off.
- Launch browsers headless; always close the browser/context when done.
- Wait for the page to settle before inspecting the DOM on dynamic prototypes.
- Report broken flows and console errors as findings; never mark the gate passed to move on.
- Do not edit orchestrator-owned tracking files directly.
- Prefer the accessibility snapshot over raw screenshots for driving actions and assertions.
