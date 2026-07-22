---
name: ait-quality-gates
description: 'Reusable quality‑gate library for the AI‑SDLC system. Use to verify that a task or change is correct before marking it done: build, lint/format, unit tests, acceptance, critic review, and security scans. Auto‑detects the project stack and runs only the gates that already exist in the repo. Use whenever a specialist finishes a task or before sign‑off/deploy.'
license: MIT
---

# Quality Gates

A shared, stack‑agnostic library of gates. Agent‑authored code passes the **same** gates as human
code. Only run tooling that **already exists** in the target repo — never invent or install new
tooling to satisfy a gate. If a required gate's tooling is absent, record it as `skipped` — a
skipped **required** gate **blocks** the task unless a human waiver is recorded in `decisions.md`.

Follow `.github/instructions/ai-sdlc.instructions.md`.

## Gate catalog (stable ids)
Core gates (code tasks):

| id | phase | verifies |
|----|-------|----------|
| `build` | build | compiles/builds with no errors |
| `lint` | build | linter & formatter clean |
| `unit` | build | unit tests pass; new code covered |
| `acceptance` | test | task's acceptance criteria demonstrably met |
| `critic` | test | Code Reviewer finds no blocking issues |
| `security` | test | secret scan, SAST, SCA, RAI pass (run via the `ait-security` skill) |

Phase gates (plan/deploy tasks):

| id | phase | verifies |
|----|-------|----------|
| `design-review` | plan | UX flows/wireframes/tokens/design direction complete & acceptance‑ready (UI work only) |
| `prototype-review` | plan | clickable prototype built & verified — flows work, no console errors, responsive, a11y smoke passes; stakeholder‑validatable (UI work only) |
| `spec-review` | plan | PRD **and** architecture/API/data model complete & internally consistent (PRD acceptance criteria validated here; no separate PRD gate) |
| `pre-deploy` | deploy | release plan + rollback plan ready; sign‑off = approved |
| `smoke` | deploy | post‑deploy smoke checks pass |
| `rollback-ready` | deploy | rollback path verified |

Each task declares its `requiredGates` (subset of the ids above). Record results in
`gateResults` as `not_run | passed | failed | skipped`. `design-review` and `prototype-review`
are scheduled **only** for user‑facing UI work; for non‑UI specs they are not created (not
`skipped`).

## Gate order
1. **build** → 2. **lint/format** → 3. **unit** → 4. **acceptance (qa)** → 5. **critic review** → 6. **security**

Run the smallest command that covers the change first; escalate to full‑suite only if targeted
runs are insufficient or the change is broad. Plan tasks run their phase gate
(`design-review` → `prototype-review` → `spec-review`); deploy tasks run `pre-deploy` → `smoke` → `rollback-ready`.

## Stack auto‑detection
Detect the stack from marker files, then choose commands:

| Marker | Stack | build | lint | unit |
|--------|-------|-------|------|------|
| `package.json` | Node/TS | `npm run build` (if script) | `npm run lint` | `npm test` / `npm run test` |
| `pyproject.toml` / `requirements.txt` | Python | `python -m build` (if configured) | `ruff check` / `flake8` | `pytest` |
| `*.csproj` / `*.sln` | .NET | `dotnet build` | `dotnet format --verify-no-changes` | `dotnet test` |
| `go.mod` | Go | `go build ./...` | `go vet ./...` | `go test ./...` |
| `pom.xml` / `build.gradle` | Java | `mvn -q compile` / `gradle build` | (checkstyle if present) | `mvn test` / `gradle test` |
| `Cargo.toml` | Rust | `cargo build` | `cargo clippy` | `cargo test` |

Always prefer an existing script (e.g. a `Makefile`, `package.json` script, or CI workflow step)
over a guessed command. Read CI config (`.github/workflows/*`) to mirror the project's real gates.

## Gate definitions
- **build** — compiles/builds with no errors.
- **lint/format** — linter and formatter report clean (or only acceptable warnings).
- **unit** — unit tests pass; new/changed code has tests covering happy + error paths.
- **acceptance** — the task's explicit acceptance criteria are demonstrably met (QA agent verifies,
  e.g. runs the endpoint/flow or an integration/e2e test).
- **critic review** — Code Reviewer finds no blocking correctness/security/maintainability issues.
- **security** — secret scan, SAST, dependency/SCA, and RAI checks pass (see `ait-security` skill).

## Output — report exactly this
Report **only the gates the task declared** in `requiredGates`. For a build/test task use the
core block:
```
### Gates — <task-id>
- build:      passed | failed | skipped (reason)
- lint:       passed | failed | skipped
- unit:       passed | failed | skipped   (N passed / M failed)
- acceptance: passed | failed | skipped
- critic:     passed | failed | skipped
- security:   passed | failed | skipped
Verdict: PASS | FAIL  (FAIL if any required gate is failed, or skipped without a waiver in decisions.md)
```
For a **plan** or **deploy** task, report its phase gate(s) instead:
```
### Gates — <task-id>
- <phase-gate>: passed | failed | skipped (reason)   # e.g. design-review / prototype-review / spec-review / pre-deploy / smoke / rollback-ready
Verdict: PASS | FAIL
```
Omit gate lines the task did not declare rather than printing `skipped` for gates that never applied.
On **FAIL**, include the failing command, the key error lines, and the smallest suggested fix.
A task may only be marked `done` when its **required** gates are `passed`.

## Notes
- Determinism: re‑run a failed gate once to rule out flakiness before declaring FAIL.
- Speed: cache detection within a run; don't re‑detect the stack every task.
- See `references/commands.md` for expanded per‑stack command recipes.
