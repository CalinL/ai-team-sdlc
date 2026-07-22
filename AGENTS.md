# AI‑SDLC — Reusable Agentic Software Delivery System

This repository contains a **reusable, spec‑agnostic agentic SDLC system**: a master
**Orchestrator** that turns any product idea/spec into shipped software by decomposing the
work into verifiable tasks, dispatching each to the right specialist **AI agent**, enforcing
**quality gates**, keeping a **resumable** record of progress, and reporting `DONE`.

It is **portable**: the reusable logic lives in **Skills** (`.github/skills/*/SKILL.md`) and
this `AGENTS.md`, which are read by **both** VS Code Copilot and the Copilot CLI. The
`.github/agents/*.agent.md` personas and `.github/prompts/*.prompt.md` commands are the VS
Code entry points; in the CLI you invoke the same skills directly (see **Running** below).

> Point it at *any* specs later and say "implement all this." It resumes from where it left
> off if a run fails, and reports `DONE` only when every task passes its gate.

---

## The team (phases → agents)

| Phase | Command | Skill | Specialist AI agent(s) | Humans in the loop |
|-------|---------|-------|------------------------|--------------------|
| 🧭 Plan | `/product-design` | `ait-product-design` | Product Designer | Product Owner, Tech Lead |
| 🧭 Plan | `/product-prototype` | `ait-product-prototype` | Product Designer | Product Owner, Tech Lead |
| 🧭 Plan | `/product-specs` | `ait-tech-specs` | Product Owner, Architect | Product Owner, Tech Lead/Architect |
| 🔨 Build | `/product-implement` | `ait-implementation` | Backend Dev, Frontend Dev | Software Engineers, Tech Lead |
| ✅ Test | `/product-qa` | `ait-qa-validation` | QA / Test | QA Lead |
| ✅ Test | `/product-review` | `ait-review-critic` | Code Reviewer / Critic | Tech Lead |
| ✅ Test | `/product-security` | `ait-security` | Security / RAI | Security Team |
| 🔐 Sign‑off | *(human gate)* | — | — | Product Owner, Security Team, Tech Lead |
| 🚀 Deploy | `/product-deploy` | `ait-deploy` | DevOps | DevOps / SRE |
| ♾️ All | `/product-run` | `ait-sdlc-orchestrate` | Orchestrator + Scribe | as above |

The **Orchestrator** (`ait-sdlc-orchestrate`) runs the whole chain; **Scribe** keeps the tracking
state consistent. See `docs/ai-sdlc-design.md` for the full design and diagrams.

### Design toolkit (companion skills for the Plan phase)
Four companion skills support the two design stages (`ait-product-design` = ideation, `ait-product-prototype`
= prototyping): three are vendored unprefixed and one (`ait-prototype-testing`) is adapted and namespaced.
They don't own a phase or gate on their own — the stage skills own the flows,
decisions, and gates (`design-review`, `prototype-review`):

| Skill | Supports | Role | Origin |
|-------|----------|------|--------|
| `frontend-design` | both | Visual craft: typography, palette, layout; avoid "AI-slop" defaults | vendored, Apache-2.0 |
| `theme-factory` | both | Concrete color/font themes to ground design tokens | vendored, Apache-2.0 |
| `web-artifacts-builder` | `ait-product-prototype` | Scaffold a **throwaway** clickable prototype (React/Tailwind/shadcn) — prototype only, not the production build | vendored, Apache-2.0 |
| `ait-prototype-testing` | `ait-product-prototype` | Verify the prototype in a real browser via the **Playwright MCP**; feeds `prototype-review` | repurposed from Anthropic `webapp-testing`, Apache-2.0 |

`ait-prototype-testing` tests the *prototype we designed* (feeds `prototype-review`); `ait-qa-validation`
tests the *product built from spec* (feeds `acceptance`) — they are deliberately separate. Vendored
skills keep their upstream `LICENSE.txt`; see `.github/skills/NOTICE.md` for attribution.


---

## Running

### VS Code Copilot
- Full run: open the **SDLC Orchestrator** agent (or run the `/product-run` prompt) and give it
  a spec path or paste the idea.
- Single phase: run any `/product-*` prompt (e.g. `/product-design` to ideate, `/product-prototype` to build a clickable prototype).

### Copilot CLI
Skills and this file are portable to the CLI. Run one of:
- `copilot -p "Use the ait-sdlc-orchestrate skill. Specs: ./specs/. Run the full SDLC and report DONE."`
- `copilot -p "Use the ait-product-design skill to shape UX flows for the feature in ./specs/checkout.md"`
- `copilot -p "Use the ait-product-prototype skill to build and verify a clickable prototype from ./specs/checkout.md"`

Install the team as a Copilot plugin — `copilot plugin marketplace add CalinL/ai-team-sdlc` then
`copilot plugin install ai-team-sdlc@ai-team-sdlc` — and its skills and agents become available in
any repo. The plugin's skills reference the `ait-conventions` skill for the shared contract, so the
system works with no repo-level instructions file. This `AGENTS.md` is auto‑read by the CLI as
onboarding and points at that contract.

---

## Shared contract (every agent MUST follow)

These conventions are the **single source of truth**. Specialist skills reference them instead
of redefining them. The authoritative long‑form version lives in the **`ait-conventions`**
skill (`plugins/ai-team-sdlc/skills/ait-conventions/SKILL.md`), which travels with the plugin so
the contract is available in any repo that installs it.

### 1. Tracking store — `.copilot-tracking/<run-id>/`
`run-id = <YYYY-MM-DD>-<kebab-slug>` (slug derived from the spec/feature name).

| File | Purpose | Writer |
|------|---------|--------|
| `state.json` | Machine‑readable run state — **canonical** source of truth (see schema) | Orchestrator |
| `plan.md` | Phases & tasks as `[ ]/[x]` checkboxes — human‑readable **projection** of `state.json` | Orchestrator |
| `tasks.md` | Atomic task table — projection of `state.json` | Orchestrator |
| `changes.md` | Append‑only log of file changes per task | Scribe (merges `inbox/`) |
| `decisions.md` | Consolidated decisions/ADRs | Scribe (merges `inbox/`) |
| `inbox/*.md` | Isolated per‑agent write files; Scribe consolidates | Specialists |
| `inbox/processed/` | Inbox files already consolidated | Scribe |

`state.json` is canonical; `plan.md` and `tasks.md` are regenerated from it. When they disagree,
`state.json` wins. The Orchestrator creates `inbox/` and `inbox/processed/` at initialization.

Specialists **never** edit `plan.md`, `tasks.md`, `decisions.md`, or `state.json` directly.
They append one file to `inbox/` (`<timestamp>-<agent>-<taskid>.md`); the Orchestrator/Scribe
consolidate. This avoids write conflicts when agents run in parallel.

### 2. `state.json` schema (canonical)
```json
{
  "runId": "2026-07-22-checkout-feature",
  "spec": "./specs/checkout.md",
  "status": "in_progress",
  "currentPhase": "build",
  "updatedAt": "2026-07-22T14:00:00Z",
  "signoff": {
    "status": "pending",
    "artifact": null,
    "approvers": { "product_owner": null, "security_team": null, "tech_lead": null },
    "grantedAt": null
  },
  "tasks": [
    { "id": "T-001", "title": "...", "owner": "ait-backend-dev", "phase": "build",
      "deps": [], "status": "done", "retries": 0,
      "requiredGates": ["build", "unit"],
      "gateResults": { "build": "passed", "unit": "passed" } }
  ]
}
```
- `status`: `pending | in_progress | blocked | done`.
- `requiredGates`: the gate ids this task must pass (subset of the catalog in the `ait-quality-gates` skill).
- `gateResults`: per‑gate result `not_run | passed | failed | skipped`. A task is `done` only when
  every required gate is `passed`.
- `signoff.status`: `pending | approved | changes_requested`. Deploy requires `approved` with all
  three `approvers` set. Any change to files/artifact/gate results **after** approval resets it to
  `pending` and loops back to Build.

### 3. Task schema (in `tasks.md`, projected from `state.json`)
`| id | title | owner | phase | deps | acceptance | requiredGates | gateResults | status |`
- `id` grammar: `T-001`, `T-002`, … (zero‑padded).
- `phase` ∈ `plan | build | test | signoff | deploy` (exactly one per task).

### 4. Handoff / result contract (what every specialist returns)
Every specialist finishes by writing **one** inbox file named
`<ts>-<agent>-<taskid>.md` where `<ts>` is a **filesystem‑safe UTC stamp** `YYYYMMDDTHHMMSSZ`
(e.g. `20260722T143001Z` — no colons, valid on Windows), and returns a compact summary:
```
### Result — <task-id> · <agent>
- Status: done | blocked
- Files: <added/modified paths>
- Gate: <which gates ran + pass/fail>
- Decisions: <key decisions, or "none">
- Next: <suggested next agent/phase, or "orchestrator">
```

### 5. Quality gates (see `ait-quality-gates` skill)
A task is **complete** only when every required gate passes. Gates auto‑detect the stack:
`build → lint → unit tests → acceptance (qa) → critic review → security (SAST/secrets/deps/RAI)`,
plus phase gates (`design-review`, `prototype-review`, `spec-review`, `pre-deploy`, `smoke`, `rollback-ready`).
Agent‑authored code passes the **same** gates as human code — no exemptions. A required gate whose
tooling is absent is `skipped` and **blocks** the task unless a human waiver is recorded in `decisions.md`.

### 6. Resume‑on‑failure
On (re)start the Orchestrator reads **`state.json`** (canonical), then reconciles `plan.md`. It:
- treats any task left `in_progress` (e.g. after a crash) as **not done** and re‑runs it,
- resumes at the first task that is `pending`/`in_progress` and whose deps are all `done`,
- retries a `failed` gate with the failure context (bump `retries`; after 2, mark `blocked`),
- surfaces `blocked` tasks to the user for an explicit unblock decision.
Finished (`done`) work is never redone. A run resumes **only** when an existing `run-id` is given;
otherwise a new `run-id` is created (append a numeric suffix if the slug already exists) so repeated
demos never resume stale state.

### 7. Human‑in‑the‑loop
The **Sign‑off** gate is mandatory before Deploy: Product Owner + Security Team + Tech Lead
approve or request changes (which loop back to Build). Agents pause and ask; they do not
self‑approve deployment. Sign‑off is **persisted** in `state.json.signoff` (approvers, artifact,
timestamp) so a resumed run can prove approval. Any change after approval resets sign‑off to
`pending`. Deploy ships the **approved artifact** only.

---

## Conventions for contributing agents
- Keep each skill single‑purpose and ≤ ~500 lines; put long reference material under the
  skill's `references/`.
- Reference shared conventions here — do **not** duplicate them.
- Do not hardcode secrets. Prefer small, verifiable, resumable steps over one large run.
- Portable Markdown only; avoid IDE‑locked mechanisms.
