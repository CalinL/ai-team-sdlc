# AI-SDLC usage

AI-SDLC is a reusable, spec-agnostic agentic software delivery system. A master Orchestrator turns
an idea, PRD, or spec into shipped software by decomposing work into verifiable tasks, dispatching
specialist AI agents, enforcing quality gates, keeping resumable tracking state, and reporting
`DONE` only after every in-scope task passes its gate.

The team ships as a GitHub Copilot plugin: `ait-` skills and agents under `plugins/ai-team-sdlc/`.
VS Code prompts and agents are thin entry points; the Copilot CLI applies the same skills directly,
with the `ait-conventions` skill as the shared contract.

## Commands

| Command | Routes to skill | Agent persona(s) | Use when |
|---|---|---|---|
| `/product-design` | `ait-product-design` | Product Designer | Ideation: explore an idea, map user journeys, shape UX flows, and produce design direction + tokens. |
| `/product-prototype` | `ait-product-prototype` | Product Designer | Prototyping: turn approved design direction into a runnable clickable prototype and verify it (Playwright MCP) before specs. |
| `/product-specs` | `ait-tech-specs` | Product Owner, Architect | Convert a validated prototype/direction into technical specs, acceptance criteria, and decisions. |
| `/product-implement` | `ait-implementation` | Backend Dev, Frontend Dev | Build an atomic task or feature slice from specs/tracking. |
| `/product-review` | `ait-review-critic` | Code Reviewer / Critic | Review implemented changes for blocking issues before completion. |
| `/product-security` | `ait-security` | Security / RAI | Run security, secrets, SAST, dependency/SCA, and RAI validation. |
| `/product-qa` | `ait-qa-validation` | QA / Test | Verify acceptance criteria and produce test evidence. |
| `/product-deploy` | `ait-deploy` | DevOps | Prepare or execute deployment after mandatory human sign-off. |
| `/product-run` | `ait-sdlc-orchestrate` | Orchestrator + Scribe | Run or resume the full Plan → Build → Test → Sign-off → Deploy lifecycle. |

## Running in VS Code Copilot

| Goal | How |
|---|---|
| Full lifecycle | Open the SDLC Orchestrator agent or run `/product-run`, then provide a spec path, folder, PRD text, or idea. |
| Single phase | Run the matching `/product-*` command, such as `/product-design` or `/product-qa`. |
| Specialist persona | Use the matching agent where available; the prompt command routes to the skill and persona. |

Commands are thin routers. The durable procedure lives in the skill; shared rules come from
the `ait-conventions` skill (and `AGENTS.md`, when present).

## Running in Copilot CLI

Install the plugin, then invoke a full run or a single phase:

```powershell
copilot plugin marketplace add CalinL/ai-team-sdlc
copilot plugin install ai-team-sdlc@ai-team-sdlc

copilot -p "Use the ait-sdlc-orchestrate skill. Specs: .\specs\. Run the full SDLC and report DONE."
copilot -p "Use the ait-product-prototype skill to build and verify a clickable prototype from .\specs\checkout.md"
```

The plugin's skills carry their own procedure and reference the `ait-conventions` skill for the
shared contract, so no repo-level instructions file is required.

## Full lifecycle with `/product-run`

| Step | What happens | Output |
|---|---|---|
| 1. Initialize or resume | Orchestrator reads a spec/idea or existing `.copilot-tracking\<run-id>\`. | Tracking store created or resumed. |
| 2. Plan | Ideation, prototyping (UI work), PRD, and tech specs shape the work. | Design direction, verified clickable prototype, PRD, specs, acceptance criteria, decisions. |
| 3. Decompose | Orchestrator breaks work into atomic tasks with owners, deps, gates, and status. | `tasks.md`, `plan.md`, `state.json`. |
| 4. Build/Test loop | Ready tasks are dispatched to implementation, QA, review, and security specialists. | Code changes, inbox handoffs, gate evidence. |
| 5. Human sign-off | Product Owner, Security Team, and Tech Lead approve or request changes. | Approval to deploy, or follow-up tasks. |
| 6. Deploy | DevOps performs release work and rollback planning after approval. | Deployment result and rollback notes. |
| 7. DONE | Orchestrator marks the run done only when every in-scope task passes required gates. | Concise `DONE` summary and tracking path. |

## Resumability

Each run writes runtime state to `.copilot-tracking\<run-id>\`, where
`run-id = <YYYY-MM-DD>-<kebab-slug>`.

| File | Purpose | Owner |
|---|---|---|
| `state.json` | **Canonical** run state (tasks, `requiredGates`/`gateResults`, `signoff`). | Orchestrator |
| `plan.md` | Checkbox plan — projection of `state.json`; `[x]` items skipped on resume. | Orchestrator |
| `tasks.md` | Atomic task table: id, owner, phase, deps, acceptance, requiredGates, gateResults, status. | Orchestrator |
| `changes.md` | Append-only file-change log. | Scribe consolidates |
| `decisions.md` | Consolidated decisions/ADRs. | Scribe consolidates |
| `inbox\*.md` | One isolated handoff file per specialist task (`inbox\processed\` once merged). | Specialists |

On restart with an existing `run-id`, `/product-run` reads `state.json` (canonical), skips `done`
tasks, re-runs any `in_progress` task (crash recovery), and continues from the first ready task
whose dependencies are satisfied. Finished work is not redone. Without a `run-id`, a fresh run is
created (so repeated demos never resume stale state).

## Quality gates

AI-authored code must pass the same gates as human-authored code. The `ait-quality-gates` skill
auto-detects the stack and runs only tooling already configured in the target repository.

| Order | Gate | Pass condition |
|---:|---|---|
| 1 | Build | Project compiles/builds without errors. |
| 2 | Lint/format | Existing linters and formatters are clean. |
| 3 | Unit | Unit tests pass; changed code is covered where applicable. |
| 4 | Acceptance (QA) | Acceptance criteria are demonstrably met. |
| 5 | Critic review | Code Reviewer finds no blocking issues. |
| 6 | Security | Secrets, SAST, dependency/SCA, and RAI checks pass where configured. |

Use the smallest command that covers the change first; escalate only when needed. Missing tooling
is reported as skipped, not invented.

## Human sign-off gate

Deployment requires human approval from the Product Owner, Security Team, and Tech Lead. Agents do
not self-approve deployment. If approval is missing, `/product-deploy` and `/product-run` pause and
surface what was built, gate results, key decisions, risks, and the exact artifact/version. Approval
is persisted in `state.json.signoff` so a resumed run can prove it. Any change after approval voids
sign-off and loops back to Build. Deploy ships the approved artifact only.
