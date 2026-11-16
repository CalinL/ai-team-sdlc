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
| 3. Decompose | Orchestrator breaks work into atomic tasks with owners, deps, gates, and status. | The committed feature `tasks.md` imported into `state.json`; `plan.md`. |
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
| `inbox\*.md` | One isolated handoff file per specialist task, summarizing and linking its committed artifacts (`inbox\processed\` once processed). | Specialists |
| Path-check baselines | Contract mode's before/after hashes. | Orchestrator |

The tracking store is agent state only, never an artifact. A run started on 1.1.1 creates nothing
else there: decisions go to the committed decision log (`architecture/adr/`), approvals to
`delivery/approvals.md`, the task plan to each feature's committed `tasks.md`, and file history
to Git. `decisions.md`, `changes.md` and `tasks.md` exist only in runs started before 1.1.1.

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

## Where the team writes

Work products are committed in spec-driven folders: the PRD, design, prototype and one folder per
feature (stories, spec, task plan) under `specs/`; decision records in `architecture/adr/`;
results, `approvals.md` and release records in `delivery/`; showcase and idea material in
`showcase/`. `docs/` is documentation only, and `.copilot-tracking/` holds agent state only. An
explicit output folder, the contract paths and your repo's rules come first; existing files are
never moved. The rules live in the `ait-artifact-layout` skill.

## Branches and pull requests

The team commits only on a feature branch. If a run starts on the default branch (or a detached
`HEAD`), it creates `ait/<run-id>` before its first commit and records it in `state.json.branch`;
on an existing feature branch it uses that branch, and a resumed run checks its branch out again.
It stages only the files of each batch, never `git add -A`, so your uncommitted work stays yours.
It never updates the default branch, merges, force-pushes or bypasses branch protection, and it
pushes or opens a pull request only when you ask or your repo's rules say so. Pull-request approval
lets people merge; it is not a gate and not the release sign-off. If approvers sign off in
pull-request comments, relay the quote or link in the session so the orchestrator can record it in
`delivery/approvals.md`. The rules live in the `ait-conventions` skill.

## Contract mode

Use contract mode when your organization already owns the requirements and the architecture, and
you want this team only for **delivery**: slicing the existing requirements into stories, a
prototype kept as the UI spec, implementation, testing and release, under your own architecture
governance. It is **opt-in**: without `.github/ai-sdlc.yml` (or without a `contract:` block in it)
nothing changes. The full rules live in the `ait-contract-mode` skill.

### Turn it on

Add `.github/ai-sdlc.yml` to the host repository. Only `contract.brief` is required; every path is
your choice, relative to the repo root. On a new run, unset paths default to the committed folders
shown below.

```yaml
# .github/ai-sdlc.yml
contract:
  brief: delivery/brief.md                  # REQUIRED. The run's brief, owned outside this team
  requirements: specs/prd.md                # OPTIONAL. An existing PRD: slice it, never rewrite it
  stages: { design: false, prototype: ui-spec }
  paths:                                    # OPTIONAL. Defaults shown (runs started on 1.1.1)
    stories: "specs/features/{feature}/stories.md"   # {feature} = the feature folder's name
    prototype: specs/ui/
    specs: specs/features/
    results: delivery/results/
  decisions: { dir: architecture/adr/, proposed_status: Proposed, accepted_status: Accepted }
  protected: [architecture/]                # the decisions.dir exception below still lets the team add a new Proposed record
  frozen: []                                # add the evaluation set when it is accepted; frozen binds every agent
  external_gates:
    - { id: prototype-accepted, before: specs, file: "specs/ui/ACCEPTED.md" }
    - { id: spec-conformance, before: build, file: "delivery/conformance/{spec}.md" }
    - { id: release-acceptance, before: signoff, file: "delivery/results/acceptance-{version}.md" }
review:
  independence: required
```

If the file exists, it is validated before anything runs. Invalid YAML, a missing `brief`, a path
with `..`, an unknown `before`, `{feature}` outside `paths.stories` or not under `paths.specs`,
duplicate gate ids or a bad `review.independence` **stop the run** with every error listed; there is
no silent fallback to default mode. Unknown keys only produce a warning. (An omitted
`paths.prototype` with `ui-spec` now means `specs/ui/` on a new run.)

### The flow

| Step | What happens | Output |
|---|---|---|
| 1. Stories | The Product Owner slices `requirements` (or the brief) into stories that cite requirement IDs and decision records. **No PRD is written.** | `paths.stories` |
| 2. Design (optional) | Only when `stages.design` is true (the default) and the work has UI. | Design direction |
| 3. Prototype (UI work) | With `ui-spec`, the prototype defines canonical `data-testid` attributes and, once accepted, is kept as the UI specification (never shipped). | `paths.prototype` |
| 4. Specs | The Architect writes implementation specs against the stories and the accepted prototype; it does not dispatch other agents. | `paths.specs` |
| 5. Build / Test | Implementation reuses the prototype's selectors; QA re-runs those flows against the build. | Code, tests, `paths.results` |
| 6. Sign-off | The usual three-approver human sign-off, plus `release-acceptance` when configured. | `delivery/approvals.md` sign-off record |
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
  in `delivery/approvals.md`). Commands to compute digests are in the skill's
  `references/path-check-and-digests.md`.
- **`path-check`** runs after every task: it fails if the task changed anything under `frozen`,
  `protected` or `decisions.dir` (adding a new `Proposed` decision record is the one exception), and
  it also runs your `path_check` command when set. It also fails if the task changed the brief, the
  requirements, an acceptance receipt or `.github/ai-sdlc.yml`, whether or not those files are
  listed under `protected`, tracked or gitignored.
- **Sign-off** is unchanged: Product Owner, Security Team and Tech Lead, recorded in `delivery/approvals.md`.

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
`delivery/approvals.md`, so they survive a new session.

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
  independence is `met` or a human waiver for that artifact version is recorded in `delivery/approvals.md`.
- Without the setting (or with `off`), the critic review is exactly as before.
