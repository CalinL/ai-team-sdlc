---
# Created by Calin Lupas with AI assistance. Credits: the repository's README.md (Authors and credits) and NOTICE.
name: ait-artifact-layout
description: 'Where every AI-SDLC work product goes and who writes it: the spec-driven default layout (specs/, architecture/adr/, delivery/, showcase/; docs/ for documentation only), the resolution order (explicit folder, contract paths, host rules, a resumed run''s recorded paths, existing version series, defaults), human-only files, the approval and release records, .copilot-tracking/ as agent state only, and the 1.1.0 locations for resumed runs. Read it whenever you write a deliverable. Not for run state (see ait-conventions).'
license: Apache-2.0
---

# Artifact Layout

Where every AI-SDLC work product goes, and who writes it. Read this skill whenever you write a
deliverable, and never invent a folder. Run state (tasks, gates, resume) is in `ait-conventions`.

## Why
`docs/` is documentation (guides, how-tos, runbooks, design rationale). Requirements, specifications, decisions, approvals and delivery records are work products, each with a committed home; `.copilot-tracking/` is the agents' local state and may summarize and link an artifact, never hold one.
The shape follows spec-driven tools: GitHub Spec Kit commits one folder per feature (https://github.com/github/spec-kit), Kiro commits `.kiro/specs/<feature>/` (https://kiro.dev/docs/specs/), and adr-tools keeps decision records in their own numbered log (https://github.com/npryce/adr-tools).

## Default layout

| Artifact | Default path | Written by |
|---|---|---|
| PRD | `specs/prd.md` | `ait-product-owner` (default mode; contract mode never writes a PRD) |
| Design: journeys, UX flows, tokens | `specs/design/` | `ait-product-designer` (when the design stage runs) |
| Prototype, notes, evidence | `specs/ui/`: `prototype-v<N>.html`, `notes.md`, `v<N>-evidence/` | `ait-product-designer` via `ait-product-prototype` |
| Prototype acceptance (contract gate) | `specs/ui/ACCEPTED.md` | a human only |
| Specs index | `specs/README.md`, written once, never overwritten | `ait-init`, or the first `ait-product-owner` task |
| Feature stories | `specs/features/<NNN-slug>/stories.md` | `ait-product-owner` |
| Implementation spec | `specs/features/<NNN-slug>/<NNN-slug>.md` | `ait-architect` |
| Feature task plan (static) | `specs/features/<NNN-slug>/tasks.md` | `ait-architect` |
| Decision record | `architecture/adr/NNN-kebab-title.md`, new and Proposed | any specialist; the architect owns architecture decisions; a human accepts |
| Small implementation decisions | the feature spec's `## Decisions` section | `ait-architect` and the developers |
| QA, review, security, evaluation results | `delivery/results/` | `ait-qa-test`, `ait-code-reviewer`, `ait-security-rai` |
| Release acceptance (contract gate) | `delivery/results/acceptance-<version>.md` | a human only |
| Sign-off record, gate confirmations, waivers | `delivery/approvals.md` (append-only), written when each happens | the orchestrator (sign-off); `ait-scribe` (the rest) |
| Release plan, rollback plan, deploy evidence | `delivery/release/` | `ait-devops` |
| Brief, conformance receipts (contract) | `delivery/brief.md`, `delivery/conformance/<spec>.md` | the architecture owner, outside this team |
| Showcase | `showcase/<product>/`: `v<N>.html` (or `v<N>/index.html`), `research.md`, `v<N>-changes.md`, `<extra>.md`, `v<N>-evidence/` | `ait-product-showcase` |
| Idea material | `showcase/<company>/`: the current file names, `<company>-` prefix kept | `ait-idea` |
| Frontend reproduction | caller's folder → repo's frontend convention → `apps/frontend/` | `ait-wireframe-to-frontend` |
| Other code, tests, infrastructure | the host's existing layout | developers, `ait-qa-test`, `ait-devops` |
| Documentation | `docs/` | humans; an agent only when asked for documentation |
| Agent state (never an artifact) | `.copilot-tracking/<run-id>/` (gitignored) | the orchestrator, `ait-scribe`, specialists' handoffs |

Code, tests and infrastructure stay in the host's existing layout. Decision records sit with the
architecture (`architecture/adr/`) in both modes, so a team that later adopts contract mode never
moves its log; `decisions.dir` can move it anywhere.

## Features, stories and tasks
1. **One slicing owner.** The product owner slices the PRD (default mode) or `contract.requirements`
   (contract mode) into feature folders: each folder is one epic or part of one, numbered
   `NNN-slug` in creation order. Requirement IDs inside the files may map many-to-many. Nobody else
   creates or re-slices feature folders; the orchestrator's decomposition reads them.
2. **Stories live in their feature**, in `stories.md`, never in one product-wide file. Story IDs are
   `S<NNN>-<n>` (feature number, story number); each story has acceptance criteria and the
   requirement IDs it covers.
3. **The spec is named after its folder**: `features/001-checkout/001-checkout.md`, never a generic
   `spec.md`. `{spec}` in `external_gates` is that name without extension, so every conformance
   receipt is unique. `spec-conformance` binds to the file digest of that one file, so edits to
   `stories.md` or `tasks.md` never make it stale.
4. **`tasks.md` is a static plan.** The architect writes it with the spec, one table row per task:
   `| ref | story | title | owner | phase | deps | acceptance | requiredGates |`. `ref` is
   `<NNN>-<n>` (feature number, task number) and `deps` cite refs. At decomposition the
   orchestrator imports each row into `state.json` under the canonical runtime id (`T-001`,
   `T-002`, …), stores `ref`, `feature` and `story` as extra task fields, and rewrites each task's
   `deps` from refs to runtime ids. From then on `state.json` is canonical and status lives only
   there and in `plan.md`, so parallel tasks and sign-off never touch the committed plan. A change
   to the plan is a new architect task before sign-off, which rewrites the file and re-imports it
   (matching by `ref`).

## Rules
1. **Decision records are committed.** Any specialist may add a **new** Proposed record in the
   decision log; the architect owns architecture decisions; only a human sets Accepted. A small
   implementation choice that doesn't merit a record goes in a `## Decisions` section of the
   feature's spec. A run started on 1.1.1 has no `decisions.md`: the decision log,
   `delivery/approvals.md` and the specs' `## Decisions` sections are the record.
2. **Approvals are committed.** The sign-off record (three approvers, verbatim quotes or
   references, the release candidate, timestamp), every gate confirmation and every waiver are
   appended to `delivery/approvals.md` **when they happen**: the orchestrator records sign-off; the
   Scribe records gate confirmations and waivers. Gate, sign-off, deploy and resume checks read
   `delivery/approvals.md`.
3. **Results and release records are committed:** results in `delivery/results/`; the release plan,
   rollback plan and deploy evidence in `delivery/release/`, written by `ait-devops` as it works.
4. **Human-only files are never written by the team:** `specs/ui/ACCEPTED.md`,
   `delivery/conformance/*`, `delivery/results/acceptance-*`, `delivery/brief.md` and the
   requirements file (contract mode), or the paths `.github/ai-sdlc.yml` sets for them.
5. **No row fits:** don't write the artifact anywhere, not even the tracking store, and never default
   to `docs/`. Return its content only in the conversational reply and ask the human where it goes.
   In a run, the inbox handoff records only the routing blocker (what the artifact is, and that it
   needs a destination); that task stays `blocked` until the human names a destination and the
   artifact is committed there. Other ready tasks continue.
6. **The release candidate and the records.** As soon as Build and Test are green, the orchestrator
   records the release candidate's commit SHA in `state.json.signoff.artifact` (both modes).
   "Any change after approval voids sign-off" is checked against that SHA. **The only changes that
   don't void it are new records:** an append to `delivery/approvals.md` (its content at the
   candidate is an unchanged prefix), a new file under `delivery/release/` that didn't exist at the
   candidate, and a new human receipt matching an `external_gates[].file` pattern (contract mode; it
   keeps its own digest and confirmation checks and its write protection). Editing or deleting an
   earlier record, or any other change, voids sign-off. The records are committed after the release
   candidate, never inside it.
7. **Only the orchestrator and the Scribe write `delivery/approvals.md`.** A dispatched specialist
   task never does; in contract mode `path-check` enforces it.
8. **The file names, the ID formats and the three acceptance gates are this team's convention;** the
   tools named under Why inform only the folder-per-feature shape and the separate decision log.

## What `.copilot-tracking/` may hold
A run started on 1.1.1 creates and writes only four kinds of agent state:

| Kept | Why |
|---|---|
| `state.json` | Canonical run state: tasks, status, gate results, lineage, `layout`, `signoff` |
| `plan.md` | The one human-readable progress view, a projection of `state.json` |
| `inbox/` (and `inbox/processed/`) | Handoffs: messages that summarize an artifact and link its committed path |
| Path-check baselines | Contract mode's before/after hashes |

| No longer created or written | Replaced by |
|---|---|
| `decisions.md` | The decision log (`architecture/adr/`), `delivery/approvals.md`, the specs' `## Decisions` sections |
| `changes.md` | Git history, plus each task's `files` in `state.json` (authorship lineage) |
| `tasks.md` (the projection) | The committed `specs/features/<NNN-slug>/tasks.md` (the plan) plus `state.json` and `plan.md` (status) |

The tracking templates for these three files stay in the plugin for runs started earlier, unused by
new runs. **No artifact's only copy lives in `.copilot-tracking/`**: deleting the folder, or cloning
the repo elsewhere, must lose no requirement, spec, decision, result, approval or release record.

**"Committed" means:** the artifact is written to a tracked path and included in a Git commit of
that path. Commits follow the host's rules: the orchestrator commits the batch's artifacts after
each batch, unless the host leaves commits to people, in which case it asks. A specialist writes its
artifact before the handoff that links it. Before recording the release candidate, the orchestrator
makes sure every artifact of the run is in a commit. The approval and release records are committed
after the candidate, in commits that touch only those paths.

## Resolution order
For each artifact, the first rule that gives a path wins. Rule 4 applies **only to a resumed run**;
a new run, or a phase skill run on its own, skips it and then records what it resolved in
`state.json.layout.paths` (when there is a run).

| # | Source | Notes |
|---|---|---|
| 1 | An output folder given explicitly on the invocation | Existing skills accept one (prototype, showcase, idea, wireframe) |
| 2 | `contract.paths` / `contract.decisions.dir` | Contract mode |
| 3 | The host repo's rules (`AGENTS.md`, `.github/copilot-instructions.md`) | Host repository rules in `ait-conventions` |
| 4 | A resumed run's recorded paths | `state.json.layout.paths`; a resumed run whose `state.json` has no `layout` (started on 1.1.0) uses the 1.1.0 table below |
| 5 | An existing version series | Only if 1–3 give nothing: the next prototype or showcase version is written beside the existing ones, and the result says so |
| 6 | The defaults above | |

**1.1.0 locations** (used by rule 4 for a resumed 1.1.0 run, and by rule 5 to find a version series):

| Artifact | 1.1.0 location |
|---|---|
| PRD, specs, stories, ADRs, results, release plan, deploy evidence | Inside the specialists' inbox handoffs (`.copilot-tracking/<run-id>/inbox/<ts>-<agent>-<task-id>.md`), consolidated by the Scribe into `decisions.md` and `changes.md`; contract mode: the `.github/ai-sdlc.yml` paths, unset `paths.*` in the handoffs, unset `decisions` in `decisions.md` |
| Sign-off record, gate confirmations, waivers | `.copilot-tracking/<run-id>/decisions.md` |
| Prototype | `docs/<product>-prototype-v<N>.html`, `docs/<product>-prototype-notes.md`, `docs/<product>-prototype-v<N>-evidence/` |
| Showcase | `docs/<product>-v<N>.html` (or `docs/<product>-v<N>/index.html`), `docs/<product>-research.md`, `docs/<product>-v<N>-changes.md`, `docs/<product>-v<N>-evidence/`, extras `docs/<product>-<extra>.md` (and `-business-case.html`) |
| Idea | `docs/<company>-research.md`, `docs/<company>-use-case-<NN>-<idea>.html`, `docs/<company>-use-case-<NN>-<idea>-brief.md` |

A run that starts on 1.1.1 records its resolved destinations in
`state.json.layout = { "version": "1.1.1", "paths": { … } }`, so a resume never re-derives them.
The team never relocates an existing work product to adopt this layout.

**Resuming a run started on 1.1.0.** It keeps its 1.1.0 **output locations** (above). Its
**approval record moves**: on the first resume under 1.1.1, the orchestrator appends the run's
existing sign-off record, gate confirmations and waivers from `decisions.md` to
`delivery/approvals.md`, verbatim and marked "carried over from
`.copilot-tracking/<run-id>/decisions.md`", commits that file, and from then on reads and writes
only `delivery/approvals.md`. Carrying the records over is an append of new records (Rules, 6). A
sign-off given before the resume stays valid **only if** the run's `signoff.artifact` is a commit SHA
and the working tree still matches it apart from new records; otherwise the orchestrator resets
`signoff` to `pending` and asks for a fresh three-approver sign-off. The run's existing
`changes.md`, `decisions.md` and `tasks.md` are left in place, read-only, and no longer written:
from the resume on, its new decisions go to the committed decision log (`decisions.dir`, or
`architecture/adr/` when unset), its approvals to `delivery/approvals.md`, and its file history to
Git and `state.json`.

## `specs/README.md` template
Write it once (via `ait-init` or the first `ait-product-owner` task); never overwrite it. The
product owner adds one index row each time it creates a feature folder.

```markdown
# Specifications

This folder holds the product's committed specifications: the PRD (`prd.md`), design notes
(`design/`), the prototype (`ui/`) and one folder per feature (`features/<NNN-slug>/`) with its
stories, its implementation spec and its static task plan. Decision records live in
`architecture/adr/`; results, approvals and release records in `delivery/`. Layout rules:
[ait-artifact-layout](https://github.com/CalinL/ai-team-sdlc/blob/main/plugins/ai-team-sdlc/skills/ait-artifact-layout/SKILL.md).

| Feature | Stories | Spec | Tasks | Decisions |
|---|---|---|---|---|
<!-- | [001-checkout](features/001-checkout/) | [stories](features/001-checkout/stories.md) | [spec](features/001-checkout/001-checkout.md) | [tasks](features/001-checkout/tasks.md) | [ADR-001](../architecture/adr/001-payment-provider.md) | -->
```
