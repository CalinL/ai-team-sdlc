# Spec → Atomic Tasks

Turn a spec/PRD/idea into a set of **atomic, verifiable tasks** the orchestrator can dispatch.

## Procedure
1. **Extract intent** — read the spec; list the user‑visible outcomes and constraints.
2. **Follow the lifecycle DAG** — plan (design/ideation → prototype → PRD → spec) precedes build;
   re‑decompose build/test tasks once design, prototype, and spec exist. Group work into
   `plan → build → test → signoff → deploy` (one phase per task).
   **UI‑applicability:** schedule the `design/ideation` and `prototype` tasks **only** when the
   spec has user‑facing UI. For API‑only, library, CLI, infrastructure, or batch work, **omit**
   both (do not schedule them and do not record their gates as `skipped`); start the plan at PRD.
3. **Cut atomic tasks** — each task is:
   - independently assignable to **one** specialist,
   - completable in a bounded change,
   - verifiable by explicit **acceptance criteria**,
   - small enough that its gates can pass or fail unambiguously.
4. **Assign owners** — pick the specialist whose domain matches (see table below).
5. **Wire dependencies** — set `deps` so shared files/contracts are built before consumers.
6. **Choose gates** — set `requiredGates` from the `ait-quality-gates` catalog ids.
7. **Emit** — write `state.json` (canonical), then project `tasks.md` + `plan.md` checkboxes.

## Owner selection
| Work | Owner slug | Phase |
|------|-----------|-------|
| UX flows, wireframes, design direction, design tokens (ideation, UI work only) | `ait-product-designer` | plan |
| Runnable clickable prototype + verification (throwaway spike, UI work only) | `ait-product-designer` | plan |
| PRD, acceptance criteria, backlog, priorities | `ait-product-owner` | plan |
| System/architecture, tech specs, API contracts, data model | `ait-architect` | plan |
| Server logic, APIs, services, DB access | `ait-backend-dev` | build |
| UI implementation, client state, accessibility | `ait-frontend-dev` | build |
| CI/CD, IaC, environments, release, rollback | `ait-devops` | deploy |
| Test plans, automated tests, acceptance verification | `ait-qa-test` | test |
| Code review, correctness, maintainability | `ait-code-reviewer` | test |
| SAST/secret/SCA scans, threat model, RAI (feeds sign‑off) | `ait-security-rai` | test |

**Plan‑phase gate assignment:** ideation task → `design-review`; prototype task → `prototype-review`;
PRD task and spec task → `spec-review` (the PRD's acceptance criteria are validated as part of
`spec-review`). There is no separate PRD gate.
## Task template (one row of `tasks.md`)
```
| id    | title                       | owner       | phase | deps  | acceptance                                                        | requiredGates            | gateResults | status  |
| T-003 | Implement POST /orders API  | ait-backend-dev | build | T-002 | Returns 201 + persists order; 400 on invalid body; unit tests cover happy+error | build,lint,unit | not_run     | pending |
```

## Sizing heuristics
- If a task touches > ~5 files or two specialists, split it.
- If acceptance criteria need "and" more than twice, split it.
- Prefer a vertical slice (one endpoint + its test) over a horizontal layer.

## Parallel safety
Tasks with no shared files and no dependency relationship may run in parallel. When file scope is
uncertain, add an optional `touches:` note (paths/globs the task will modify) so the orchestrator
can detect conflicts; if scope can't be bounded, dispatch the task serially.
