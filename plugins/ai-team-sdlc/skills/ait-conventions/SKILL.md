---
name: ait-conventions
description: 'Authoritative shared contract for the AI-SDLC agentic team (ait- agents and skills): tracking store, task schema, handoff/result contract, quality gates, resumability, difficulty gating, and human sign-off. Read and follow this whenever you act as any ait- specialist, orchestrator, or scribe.'
---

# AI-SDLC — Shared Conventions

These are the authoritative conventions for every specialist agent and skill in this system.
The individual skills and agents reference (do not duplicate) this contract. This skill is the
portable single source of truth: it travels with the `ai-team-sdlc` plugin, so the team behaves
identically in any repo, with no repo-level instructions file required. `AGENTS.md` (when present)
is a short pointer to this skill; `docs/ai-sdlc-design.md` holds the design rationale.

## Roles & ownership
- **Orchestrator** (`ait-sdlc-orchestrate`): decomposes specs → tasks, dispatches to specialists,
  enforces gates, owns `plan.md` / `tasks.md` / `state.json`, reports `DONE`.
- **Scribe**: consolidates `inbox/*.md` into `decisions.md` and `changes.md`; keeps history tidy.
- **Specialists**: do the work for their phase, run their gate, write **one** `inbox/` file,
  return the result summary. They never edit orchestrator‑owned files directly.

## Lifecycle DAG (canonical order)
The Orchestrator drives this dependency graph; each stage's outputs feed the next:

```
idea → design/ideation (ait-product-designer) → prototype (ait-product-designer, verified via ait-prototype-testing)
     → PRD (ait-product-owner) → spec/architecture (ait-architect)
     → final decomposition → implementation (ait-backend-dev / ait-frontend-dev)
     → QA acceptance (ait-qa-test) → critic review (ait-code-reviewer) → security (ait-security-rai)
     → human sign-off → deploy (ait-devops) → DONE
```

- **Plan** produces design → prototype → PRD → spec **before** implementation tasks are finalized.
  If the idea is thin, do a first decomposition to schedule the plan‑phase tasks, then
  **re‑decompose** the build/test tasks once design, prototype, and spec exist.
- **UI applicability:** the `design/ideation` and `prototype` tasks apply **only** to user‑facing
  UI work. For API‑only, library, CLI, infrastructure, or batch specs, omit them and start the plan
  at PRD (do not record their gates as `skipped`).
- Phase mapping for owners: design/prototype/PRD/spec = `plan`; implementation = `build`;
  QA + critic review + security = `test`; sign‑off = `signoff`; release = `deploy`.
- Plan‑phase gates run in order: `design-review` (ideation) → `prototype-review` (prototype) →
  `spec-review` (PRD **and** spec — the PRD's acceptance criteria are validated as part of
  `spec-review`; there is no separate PRD gate). Prototyping is a **throwaway spike** to validate
  UX; production UI is built in `build` by `ait-frontend-dev`, never shipped from the prototype.
- Each task carries exactly one phase; `ait-security-rai` findings feed the `signoff` gate but its
  task's phase is `test`.

## Tracking store — `.copilot-tracking/<run-id>/`
`run-id = <YYYY-MM-DD>-<kebab-slug>` (append a numeric suffix if the slug already exists).
- `state.json` — machine‑readable run state; **canonical** source of truth.
- `plan.md` — phases & tasks as `[ ]/[x]` checkboxes; human‑readable projection of `state.json`.
- `tasks.md` — atomic task table; projection of `state.json`.
- `changes.md` — append‑only file‑change log (written by Scribe from `inbox/`).
- `decisions.md` — consolidated decisions/ADRs (written by Scribe from `inbox/`).
- `inbox/<ts>-<agent>-<taskid>.md` — isolated per‑agent writes; `<ts>` = `YYYYMMDDTHHMMSSZ`
  (filesystem‑safe UTC, no colons — valid on Windows).
- `inbox/processed/` — inbox files already consolidated by Scribe.

`.copilot-tracking/` is runtime state and should be git‑ignored by consuming projects.
When `plan.md`/`tasks.md` disagree with `state.json`, `state.json` wins.

### Task schema (`tasks.md`, projected from `state.json`)
`| id | title | owner | phase | deps | acceptance | requiredGates | gateResults | status |`
- `id` grammar: `T-001`, `T-002`, … (zero‑padded).
- `owner` = specialist agent slug (e.g. `ait-backend-dev`).
- `phase` ∈ `plan | build | test | signoff | deploy` (exactly one per task).
- `deps` = comma‑separated task ids, or `-`.
- `status` ∈ `pending | in_progress | blocked | done`.
- `requiredGates` = the gate ids the task must pass; `gateResults` = per‑gate result
  `not_run | passed | failed | skipped`.

### `state.json`
Canonical run state: `runId`, `spec`, `status`, `currentPhase`, `updatedAt`, `signoff`, and the
`tasks` array (each with `retries`, `requiredGates`, `gateResults`). Keep it in sync whenever a
task status or gate result changes; regenerate `plan.md`/`tasks.md` from it.

## Handoff / result contract
Every specialist ends with exactly one `inbox/` file and returns:
```
### Result — <task-id> · <agent>
- Status: done | blocked
- Files: <added/modified paths, or "none">
- Gate: <gates run + pass/fail>
- Decisions: <key decisions, or "none">
- Next: <suggested next agent/phase, or "orchestrator">
```
Blocked tasks MUST state the blocker and what is needed to unblock.

## Quality gates (authoritative order)
Core gates:
1. **build** — project builds/compiles.
2. **lint/format** — linter & formatter clean.
3. **unit** — unit tests pass; new code has tests.
4. **acceptance (qa)** — task's acceptance criteria verified (QA agent).
5. **critic review** — Code Reviewer finds no blocking issues.
6. **security** — SAST, secret scan, dependency/SCA, and RAI checks pass.

Phase gates (used by plan/deploy tasks): **design-review** (design artifacts complete &
acceptance‑ready), **prototype-review** (clickable prototype built & verified — flows work, no
console errors, responsive, a11y smoke), **spec-review** (spec/API/data model complete &
consistent), **pre-deploy** (release + rollback plan ready), **smoke** (post‑deploy smoke checks),
**rollback-ready** (rollback verified). The full catalog with ids lives in the `ait-quality-gates` skill.

Use the smallest command that covers the change; escalate to full‑suite only when needed. Only
run gates that already exist in the target repo — never invent tooling. A required gate whose
tooling is absent is `skipped` and **blocks** the task unless a human waiver is recorded in
`decisions.md`. A task is `done` only when every required gate is `passed`. Agent‑authored code
passes the **same** gates as human code.

## Resume‑on‑failure
On (re)start: read **`state.json`** (canonical), then reconcile `plan.md`. Skip `done` tasks;
treat any `in_progress` task (e.g. after a crash) as not done and re‑run it; resume at the first
`pending`/`in_progress` task whose `deps` are all `done`. Retry a `failed` gate with the failure
context (bump `retries`; after 2, mark `blocked` and surface to the user). Never redo finished work.
Resume an existing run **only** when its `run-id` is supplied; otherwise start a fresh run.

## Difficulty‑gated execution (avoid over‑engineering)
- Every `/product-run` (full lifecycle) uses **full tracking** (`state.json` + projections).
- Standalone single‑phase commands on **Simple/Medium** tasks may use minimal tracking.
- **Hard/Challenging** tasks (cross‑cutting, many files, high ambiguity): create full tracking
  artifacts and dispatch subagents; parallelize independent tasks.

## Human‑in‑the‑loop
- **Sign‑off** before Deploy is mandatory: Product Owner + Security Team + Tech Lead approve or
  request changes. Agents pause and ask; they never self‑approve a deploy. Sign‑off is
  **persisted** in `state.json.signoff` (all three approvers, artifact/version, timestamp) so a
  resumed run can prove approval. Each approver entry MUST be sourced from a real human turn and
  backed by an append‑only `decisions.md` sign‑off record capturing the approver's identity and a
  verbatim quote/reference of the approval; agents must never populate approvers themselves. Deploy
  validates that record, not just the mutable `state.json` fields. Any change to files, artifact, or
  gate results **after** approval resets `signoff.status` to `pending` and loops back to Build.
  Deploy ships the approved artifact only.
- Surface risky/destructive actions (data migrations, infra changes) for explicit approval.

## Portability & safety
- Skills are the portable source of truth (VS Code + CLI). Agents/prompts are VS Code wrappers.
- Do not hardcode secrets. Prefer small, verifiable, resumable steps.
- Keep skills ≤ ~500 lines; move detail to `references/`.