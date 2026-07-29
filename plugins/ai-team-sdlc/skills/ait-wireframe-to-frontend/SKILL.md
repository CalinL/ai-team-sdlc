---
name: ait-wireframe-to-frontend
description: Convert an existing visual design (wireframes, mockups, a prototype PDF, screenshots, or a Figma export) into a faithful, clickable frontend built with mock data. Use this whenever the user provides a source design and wants it turned into a working frontend, a clickable prototype, or a high-fidelity HTML reproduction. Covers design-token and component extraction, screen scaffolding, faithful reproduction, and Playwright validation with screenshot comparison. Do NOT use for backend, API, or database work, or for greenfield UI with no source design to reproduce.
license: Apache-2.0
---

# Wireframe to Frontend

Turn wireframes, mockups, or design specs into a **faithful, fully clickable frontend application**
driven by **mock data**. The output is frontend-only: no backend, and no build step unless the
chosen stack or the user requires one.

Use this skill standalone, or as the **faithful-reproduction engine** that `ait-product-showcase`
delegates to when a visual design already exists. Handoff depends on how you are invoked:
- **Delegated sub-step of `ait-product-showcase`** — return your artifacts and validation evidence
  directly to the parent skill; do **not** write your own inbox file or Result block.
- **Standalone lifecycle task** — follow the `ait-conventions` skill: write exactly one inbox
  handoff and return the standard Result block.
- **Direct user request outside a run** — just build and report; no tracking files are required.

The guiding rule is **faithful reproduction**. Reproduce the source design exactly (colors, layout,
typography, spacing, components, iconography, tone of voice). Do not invent design elements,
layouts, interactions, or flows that are not present in the source.

## Prerequisites

Confirm the capabilities each phase needs before relying on them, and adapt when one is missing:

- Rendering the source to images (PDF-to-image export, or provided image/Figma assets).
- Text extraction or OCR for capturing labels, values, and copy verbatim.
- A local static server plus Playwright driving a Chromium/Chrome browser.
- A screenshot or image-diff capability for the comparison in Phase 3.

If a source is inaccessible (locked Figma, unreadable OCR, missing fonts/assets), request the
missing material rather than guessing.

## When to use

- The user provides wireframes, mockups, a design spec, a prototype PDF, screenshots, or a Figma
  export and wants a working or clickable frontend built from them.
- The user wants a high-fidelity, faithful HTML reproduction of an existing design.
- The user wants a demo-ready, executive-facing prototype driven by mock data.

## When NOT to use

- Backend, API, database, or real data-layer work.
- Greenfield UI design with no source design to reproduce (there is nothing to match against).

By default the output is **static, self-contained plain HTML + vanilla CSS/JS with no build step**.
Use a framework (e.g. React) **only** when the user explicitly requests it or existing repository
conventions require it — do not introduce a framework or build step on your own.

## Inputs

| Input | Required | Notes |
|-------|----------|-------|
| source design | yes | Wireframes as PDF, images, Figma export, or a written design spec. |
| screen scope | no | Which pages/screens are in scope. Exclude covers, architecture diagrams, and other non-UI pages. |
| output location | no | Target folder for the app. Prefer a user-provided path or the repository's existing frontend convention; otherwise default to `apps/frontend/`. |
| stack | no | **Default to static HTML + vanilla CSS/JS with no build step.** Use a framework (e.g. React) only when the user explicitly requests it or repository conventions require it. |
| brand guidance | no | Existing brand tokens, fonts, or a style guide to align with. |

## Source-quality gate

Fidelity is bounded by the source. Before promising a pixel-perfect result, check what the source
supports:

- **Dimensioned, high-resolution frames** (crisp exports or Figma with sizes) support a
  pixel-perfect claim.
- **Low-resolution images or a written spec** support only a close, faithful interpretation.
  State this limitation and request dimensions, fonts, assets, and missing states before building.
- Note missing fonts, icons, or interaction states as assumptions and confirm them with the user.

## Procedure

Work through the phases in order. Run autonomously and iterate; do not stop at a partial result.

### Phase 0: Extract the design (fidelity foundation)

Establish ground truth before writing any app code.

1. Identify the in-scope screens. Ask the user to confirm scope only if it is ambiguous; otherwise
   infer it (exclude covers, table-of-contents, and architecture/non-UI pages).
2. Render each source page to a **high-resolution image** and record its **dimensions**. For PDFs,
   export one image per page. Extract or OCR the text of each page so labels, values, and copy are
   captured verbatim.
3. Write a short **screen spec** per screen: layout regions, components, labels, and only the
   states and interactions **evidenced by the source** (for example a visible tab bar, filter
   control, or hover state). Do not add behaviors the source does not show.
4. Build a **screen-and-state inventory** listing every screen plus each reachable state to build
   and later validate (default, tab/menu variants, dialogs, filtered/empty/error, responsive
   breakpoints when specified).
5. Extract **design tokens**: brand colors, typography scale, spacing, radii, shadows, iconography,
   and component patterns (buttons, cards, tables, forms, nav, chips, badges).

Keep extraction artifacts (page images, OCR text, comparison screenshots) in a working/session
folder, not committed to the repo unless the user wants them.

### Phase 1: Scaffold the app and design system

1. Choose the app structure from the selected stack, repository conventions, and the source
   design's navigation model (single-page with a view-router, multi-page, or a framework layout).
   Do not assume a specific architecture; match what the design and stack imply.
2. Create a folder structure appropriate to that choice, separating design tokens, components,
   views/screens, mock data, and assets.
3. Implement the extracted design tokens as shared style variables.
4. Build the **app shell**: the persistent chrome (header, sidebar, nav) exactly as the source
   shows, plus the navigation mechanism needed to move between screens.

### Phase 2: Build each screen

For every in-scope screen:

1. Build the markup and styling to match the source as closely as its quality allows.
2. Wire **mock data** and **only the interactions evidenced by the source** so the flow is
   genuinely clickable. When an interaction is ambiguous, choose the most conservative faithful
   behavior and record it as a documented assumption rather than inventing new functionality.
3. Keep components consistent with the shared design system built in Phase 1.

### Phase 3: Validate with Playwright and screenshot comparison

Use a reproducible protocol so results are consistent:

1. Serve the app locally and drive it with Playwright in Chromium/Chrome.
2. Set the browser **viewport to match each source page's dimensions**, and wait for fonts, images,
   and assets to finish loading before capturing.
3. For every entry in the Phase 0 screen-and-state inventory, drive the app into that state, then
   capture a screenshot and **compare it against the matching source** using an overlay or
   pixel-diff. Record the diff and keep the evidence.
4. Add **functional assertions** alongside screenshots (navigation works, tabs/menus/dialogs open,
   filters apply, errors render) so behavior is verified, not just appearance.
5. Log every layout, design, and functionality discrepancy, then fix it. Repeat until each screen
   and state matches its source within an agreed tolerance.

### Phase 4: Review loop

1. Have the work reviewed for fidelity, defects, and usability evidenced by the source. When
   supported, run independent review subagents (optionally with a second model); otherwise perform
   a structured self-review against the screen-and-state inventory and fidelity rules.
2. Constrain feedback to fidelity, defects, and usability. Do not redesign or add elements the
   source does not contain. Incorporate the feedback and repeat until polished.

### Phase 5: Final per-screen sign-off

1. Re-verify every screen and state against its source via the Phase 3 protocol.
2. Confirm the full clickable flow works end-to-end and fix all remaining issues.

## Fidelity rules

- Match the source exactly: colors, layout, typography, components, UI/UX.
- Do not invent design elements, layouts, or interactions absent from the source. When ambiguous,
  choose the most conservative faithful option and record it as an assumption.
- Keep the design consistent with the brand's visual identity and tone of voice.
- Frontend only. Use mock data to simulate backend behavior; do not implement a backend.

## Acceptance criteria

The work is done when the application in the output folder:

- Reproduces every in-scope screen and state against the source within the agreed tolerance (or the
  best faithful interpretation the source quality allows, with limitations stated).
- Is fully clickable end-to-end using mock data, with the Phase 3 functional assertions passing.
- Passes the Playwright validation protocol with screenshot comparison across the screen-and-state
  inventory.
