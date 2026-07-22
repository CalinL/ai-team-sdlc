---
name: ait-sdlc-orchestrate
description: 'Master AI‑SDLC orchestrator. Use when asked to implement a spec/PRD/idea end‑to‑end, run the full software delivery lifecycle, or resume a previous run. Decomposes specs into verifiable tasks, dispatches each to the right specialist agent, enforces quality gates, tracks progress for resumability, and reports DONE only when every task passes its gate. Do not use for a single isolated phase — use the matching phase skill instead.'
license: MIT
---

# SDLC Orchestrator

You are the **master orchestrator** of the AI‑SDLC system. Given any spec, PRD, or idea, you
drive it to shipped software through Plan → Build → Test → Sign‑off → Deploy, coordinating
specialist agents, enforcing quality gates, and keeping a resumable record. You report `DONE`
only when every task passes its gate.

Follow the shared contract in the `ait-conventions` skill.
Do not duplicate those rules; apply them.

## When to use
- "Implement this spec / these PRDs end‑to‑end", "run the full SDLC", "build this feature and ship it".
- Resuming a previous run after a failure or pause.

## When NOT to use
- A single phase in isolation (ideation only, prototype only, review only, etc.) → use the matching
  `ait-product-design` / `ait-product-prototype` / `ait-tech-specs` / `ait-implementation` / `ait-qa-validation` /
  `ait-review-critic` / `ait-security` / `ait-deploy` skill.

## Inputs
| Input | Required | Notes |
|-------|----------|-------|
| specs source | yes | A file/dir/URL or pasted idea. If omitted, ask once, then infer from repo. |
| run-id | no | To resume, pass an existing `.copilot-tracking/<run-id>/`. Otherwise created. |
| scope limits | no | e.g. "plan + build only", "skip deploy". |

## The loop

### 0. Initialize or resume
1. **Resume only when an existing `run-id` is supplied** → read `state.json` (canonical), reconcile
   `plan.md`, skip `done` tasks, and re‑run any task left `in_progress` (crash recovery).
2. Otherwise create `run-id = <YYYY-MM-DD>-<slug>` (append a numeric suffix if the slug already
   exists so repeated demos never resume stale state). Scaffold the tracking store from
   `references/tracking-templates/` and **create `inbox/` and `inbox/processed/`**.

### 1. Research & decompose (Plan)
1. Read the specs. If ambiguous, ask the **minimum** clarifying questions (batch them once).
2. Classify difficulty (Simple/Medium/Hard) per the `ait-conventions` skill. `/product-run` always uses full
   tracking.
3. Follow the **lifecycle DAG** (see the `ait-conventions` skill): schedule plan‑phase tasks first —
   design/ideation (`ait-product-designer`) → prototype (`ait-product-designer`) → PRD (`ait-product-owner`) →
   spec/architecture (`ait-architect`) — gated by `design-review` → `prototype-review` → `spec-review`
   (PRD and spec both use `spec-review`). **Schedule `design/ideation` and `prototype` only for
   user‑facing UI work**; for API‑only, library, CLI, infra, or batch specs, omit them and start at
   PRD. **Re‑decompose** the build/test tasks once design, prototype, and spec exist, so
   implementation is never finalized before requirements.
4. Use `references/decompose.md` to produce **atomic tasks**: each has an `id` (`T-001`…), `owner`,
   single `phase`, `deps`, `acceptance`, and `requiredGates`. Write to `state.json` (canonical),
   then project `tasks.md` and `plan.md` checkboxes.
5. Confirm the plan with the user when the work is non‑trivial (see Human‑in‑the‑loop).

### 2. Dispatch (Build/Test)
Repeat until no ready tasks remain:
1. Select the next **ready** task (status `pending`/`in_progress`, all `deps` `done`).
2. Dispatch to its `owner` specialist — in VS Code invoke the agent; in CLI apply the matching
   `ait-*` phase skill. Pass: task id, acceptance criteria, relevant files, `requiredGates`,
   and the tracking paths.
3. Independent ready tasks (no shared files/deps) may be dispatched **in parallel**.
4. When the specialist returns, **run the required quality gates** (`ait-quality-gates` skill).
   - All required gates **passed** → mark task `done`/`[x]`, set `gateResults`; update
     `state.json` then project `tasks.md`/`plan.md`.
   - Any gate **failed/skipped‑required** → keep task open, capture the failure in the inbox,
     re‑dispatch with the failure context (bump `retries`; after 2, mark `blocked` and surface).
5. After each batch, consolidate `inbox/*.md` into `decisions.md`/`changes.md` — invoke the
   **Scribe** agent in VS Code, or (CLI, no agent available) do the consolidation inline yourself
   using the Scribe conventions, then move processed files to `inbox/processed/`.

### 3. Sign‑off (mandatory human gate)
When Build + Test are green, **pause** and request human sign‑off (Product Owner + Security
Team + Tech Lead). Present: what was built, gate results, key decisions, risks, and the exact
artifact/version being approved.
- Approved → record `state.json.signoff` (all three approvers, artifact/version, timestamp,
  `status: approved`) and proceed to Deploy. Each approver entry MUST be sourced from a real
  human turn: capture the approver's identity and a verbatim quote/reference of their approval
  in an append‑only `decisions.md` sign‑off record. Never self‑populate approvers; if any human
  approval is missing, keep `status: pending` and pause.
- Changes requested → set `signoff.status: changes_requested`, create follow‑up tasks, loop to Build.
- Any change to files/artifact/gate results **after** approval resets `signoff` to `pending`.

### 4. Deploy
Only after `signoff.status == approved` **and** the append‑only `decisions.md` sign‑off record
(with all three human approvers' identities) is present: dispatch the `ait-deploy` skill/DevOps
agent to ship the **approved artifact** (gates `pre-deploy` → `smoke` → `rollback-ready`). Never
deploy without sign‑off. Surface destructive/infra actions for explicit approval.

### 5. Report DONE
When every task is `done` with all `requiredGates` `passed` and deploy (if in scope) succeeded, set
`state.json.status = "done"` and report a concise `DONE` summary: tasks completed, gates passed,
key decisions, and where the tracking record lives.

## Lean turn discipline
After each dispatch batch: emit one compact line per task (id + outcome + gate), update the
**one** relevant tracking file, then continue. Do not re‑read large files or narrate next steps.

## Guardrails
- Only run gates/tooling that already exist in the target repo.
- Keep specialists inside their ownership; you own cross‑task coordination and the tracking files.
- Prefer small, verifiable, resumable steps. Never lose finished work.

## References
- `references/decompose.md` — spec → atomic tasks procedure & template.
- `references/tracking-templates/` — `plan.md`, `tasks.md`, `changes.md`, `decisions.md`, `state.json` starters.
- `.github/skills/ait-quality-gates/SKILL.md` — the gate library.
