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
| `/product-idea` | `ait-idea` | Default agent (web research) | Use-case discovery: research a company from its website, rank ideas, and produce one-page HTML use cases plus build-ready prototype briefs. Portable as a single file (also works in Cowork). |
| `/product-design` | `ait-product-design` | Product Designer | Ideation: explore an idea, map user journeys, shape UX flows, and produce design direction + tokens. |
| `/product-prototype` | `ait-product-prototype` | Product Designer | Prototyping: turn approved design direction into a runnable clickable prototype and verify it (Playwright MCP) before specs. |
| `/product-showcase` | `ait-product-showcase` | Product Designer | Executive-showcase prototyping: build a polished, presentation-ready static-HTML prototype from a spec, or faithfully reproduce an existing visual design (composes `ait-wireframe-to-frontend`). |
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

# already installed? pull the latest agents, skills, and prompts
copilot plugin update ai-team-sdlc@ai-team-sdlc

copilot -p "Use the ait-sdlc-orchestrate skill. Specs: .\specs\. Run the full SDLC and report DONE."
copilot -p "Use the ait-product-prototype skill to build and verify a clickable prototype from .\specs\checkout.md"
copilot -p "Use the ait-product-showcase skill to build an executive showcase prototype from .\specs\checkout.md"
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

## Contract mode

Use contract mode when your organization already owns the requirements and the architecture, and
you want this team only for **delivery**: slicing the existing requirements into stories, a
prototype kept as the UI spec, implementation, testing and release, under your own architecture
governance. It is **opt-in**: without `.github/ai-sdlc.yml` (or without a `contract:` block in it)
nothing changes. The full rules live in the `ait-contract-mode` skill.

### Turn it on

Add `.github/ai-sdlc.yml` to the host repository. Only `contract.brief` is required; every path is
your choice, relative to the repo root.

```yaml
# .github/ai-sdlc.yml  (all paths are the host repo's choice)
contract:
  brief: docs/delivery/brief.md        # REQUIRED. The run's spec (owned outside this team)
  requirements: docs/requirements.md   # OPTIONAL. An existing PRD: slice it, never rewrite it
  stages:
    design: false                      # OPTIONAL, default true. false = skip design/ideation
    prototype: ui-spec                 # OPTIONAL, default spike. ui-spec = keep as the UI spec
  paths:                               # OPTIONAL. Where deliverables go (tracked)
    stories: docs/delivery/stories.md
    prototype: docs/delivery/prototype/
    specs: docs/delivery/specs/
    results: docs/delivery/results/
  decisions:                           # OPTIONAL. An external decision log
    dir: docs/adr/
    proposed_status: Proposed          # specialists may only ADD new records with this status
    accepted_status: Accepted          # only humans set this
  protected: [docs/architecture/]      # OPTIONAL. Never edited by the team
  frozen: [tests/contract/]            # OPTIONAL. Never edited (e.g. an agreed evaluation set)
  path_check: scripts/check-paths.sh   # OPTIONAL. Extra check command; non-zero exit = fail
  external_gates:                      # OPTIONAL. Human acceptance files (schema below)
    - id: prototype-accepted
      before: specs                    # one of: stories | prototype | specs | build | signoff
      file: docs/delivery/prototype/ACCEPTED.md
    - id: spec-conformance
      before: build
      file: docs/delivery/conformance/{spec}.md
    - id: release-acceptance
      before: signoff
      file: docs/delivery/results/acceptance-{version}.md
review:                                # OPTIONAL (G4); works with or without contract
  independence: off                    # off | warn | required
```

If the file exists, it is validated before anything runs. Invalid YAML, a missing `brief`, a path
with `..`, an unknown `before`, `ui-spec` without `paths.prototype`, duplicate gate ids or a bad
`review.independence` **stop the run** with every error listed; there is no silent fallback to
default mode. Unknown keys only produce a warning.

### The flow

| Step | What happens | Output |
|---|---|---|
| 1. Stories | The Product Owner slices `requirements` (or the brief) into stories that cite requirement IDs and decision records. **No PRD is written.** | `paths.stories` |
| 2. Design (optional) | Only when `stages.design` is true (the default) and the work has UI. | Design direction |
| 3. Prototype (UI work) | With `ui-spec`, the prototype defines canonical `data-testid` attributes and, once accepted, is kept as the UI specification (never shipped). | `paths.prototype` |
| 4. Specs | The Architect writes implementation specs against the stories and the accepted prototype; it does not dispatch other agents. | `paths.specs` |
| 5. Build / Test | Implementation reuses the prototype's selectors; QA re-runs those flows against the build. | Code, tests, `paths.results` |
| 6. Sign-off | The usual three-approver human sign-off, plus `release-acceptance` when configured. | `decisions.md` sign-off record |
| 7. Deploy | Unchanged: ships the approved artifact only. | Release evidence |

### The gates

- **External acceptance gates** are preconditions checked **before** a task of kind `before` is
  dispatched. A human writes the receipt file (the team never does):

  ```markdown
  ---
  status: accepted            # accepted | rejected
  accepted_by: <name>         # a human
  accepted_at: <ISO date>
  artifact: <path accepted>
  digest: <digest of the accepted artifact>
  ---
  <free text: conditions, notes>
  ```

  The `digest` binds the acceptance to content: SHA-256 of a file, SHA-256 of a canonical manifest
  for a folder (receipts excluded), or the release candidate's commit SHA. Any later change (for
  example a new `-v<N+1>` prototype) makes the acceptance **stale**. The gate is met only when the
  receipt is accepted, the digest is current, and you have confirmed it once in the chat (recorded
  in `decisions.md`). Commands to compute digests are in the skill's
  `references/path-check-and-digests.md`.
- **`path-check`** runs after every task: it fails if the task changed anything under `frozen`,
  `protected` or `decisions.dir` (adding a new `Proposed` decision record is the one exception), and
  it also runs your `path_check` command when set.
- **Sign-off** is unchanged: Product Owner, Security Team and Tech Lead, recorded in `decisions.md`.

### Pause and resume

A task whose gate isn't met is `blocked` (`blockedBy: external:<id>`) without using a retry; a
change to a protected path or an accepted decision becomes a new `Proposed` record and blocks its
story (`blockedBy: decision:<id>`). Other ready tasks keep running, and the run pauses only when
nothing is ready. To continue, write or update the receipt (or accept/reject the record), confirm
in the chat, and resume with the same `run-id`:

```powershell
copilot -p "Use the ait-sdlc-orchestrate skill. Resume run-id 2026-11-07-checkout."
```

Blocked tasks are re-checked on every loop and every resume; confirmations persist in
`decisions.md`, so they survive a new session.

## Reviewer independence

Optionally, the critic review can check that its reviewer comes from a **different model family**
than the models that wrote the code. It works with or without contract mode:

```yaml
# .github/ai-sdlc.yml
review:
  independence: warn                   # off (default) | warn | required
```

- Each task records `files` and `authorModels` (when the host reports the model; otherwise
  `unknown`). The lineage of a reviewed file is the union of its tasks' models, mapped to families
  (`gpt-*`/`o*` → OpenAI, `claude-*` → Anthropic, `gemini-*` → Google, `grok-*` → xAI).
- Independence is **met** when the lineage is complete and the reviewer's family isn't in it. If
  not, the reviewer asks you to re-run the review in a session on a qualifying model family; it
  never picks models itself. Lineage with `unknown`, `auto` or a router such as `fusion` is
  **incomplete**, so independence is `unknown`.
- With `warn`, the critic gate can pass with a warning. With `required`, it fails unless
  independence is `met` or a human waiver for that artifact version is recorded in `decisions.md`.
- Without the setting (or with `off`), the critic review is exactly as before.
