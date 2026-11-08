---
name: ait-contract-mode
description: 'Contract mode for the AI-SDLC team: deliver from a brief and existing requirements under an external architecture owner, with a kept UI-spec prototype, human acceptance gates, an external decision log and protected paths. Use only when the host repo has .github/ai-sdlc.yml with a contract block; never otherwise.'
license: Apache-2.0
---

# Contract Mode

Contract mode lets a team that already owns its requirements and architecture use the AI-SDLC
team for **delivery only**: slicing existing requirements into stories, a prototype kept as the UI
specification, implementation, testing and release, under the host's own architecture governance.
It is **opt-in** and changes nothing unless the host repository turns it on.

Follow the `ait-conventions` skill. Its **safety floors** (Host repository rules) apply in every
mode and are never weakened here. This skill holds **all** contract-mode rules; other skills only
point to its numbered sections (e.g. "`ait-contract-mode` §7").

## When to use
- The host repo has `.github/ai-sdlc.yml` **with a `contract:` block**, and you are the
  orchestrator or any `ait-` specialist working in that repo.
- A phase skill (e.g. `ait-product-prototype`, `ait-tech-specs`) runs on its own in such a repo:
  it reads and validates the file directly (§1) and checks its own preconditions (§7).

## When NOT to use
- There is no `.github/ai-sdlc.yml`, or it has no `contract:` block → default lifecycle, exactly as
  defined in `ait-conventions` and `ait-sdlc-orchestrate`. Do not apply any rule below.
- The file has only a `review:` block → reviewer independence only (`ait-review-critic`); the run
  stays in default mode (the file is still validated, §1).
- Writing a new PRD, or inventing or rewriting the brief → never, in any mode of this skill.
- Choosing models, reviewers or run limits → the host owns those; this skill adds none.

## Inputs
| Input | Required | Notes |
|-------|----------|-------|
| `.github/ai-sdlc.yml` | yes | The activation switch and configuration (§1). Schema and example: `references/config-and-receipts.md`. |
| `contract.brief` | yes | The run's spec, owned outside this team (§2). |
| `contract.requirements` | no | An existing PRD to slice into stories, never rewrite (§3). |
| acceptance receipts | no | Human-written files named by `contract.external_gates` (§7). |
| tracking path | yes | `.copilot-tracking/<run-id>/`; `state.json` stays canonical (§11). |
| task-id + task kind | for specialists | Passed by the orchestrator; kinds are listed in §4. |

## Procedure
1. **Activate** (§1): read and validate `.github/ai-sdlc.yml`; on any error, stop and list the
   errors. Record `mode: contract` in `state.json`.
2. **Plan** from the brief (§2) and requirements (§3) in the architecture-first order (§4).
3. Before **every** dispatch: check the external gates for the task's kind (§7) and record the
   `path-check` baseline (§10).
4. Dispatch; the specialist applies §5, §6, §8, §9 and §11 for its task kind.
5. After the task: run its gates, including `path-check` (§10). Record decisions (§8) and change
   requests (§9).
6. On every loop iteration and every resume: re-check blocked tasks (§7, §9).
7. Before sign-off: record the release candidate (§13) and check `release-acceptance` (§7).
8. Return the Output block (§12).

### 1. Activation
- Contract mode is active **only** when `.github/ai-sdlc.yml` exists **and** has a `contract:`
  block. The orchestrator detects it at step 0 and records `"mode": "contract"` in `state.json`
  (otherwise `"default"`). A phase skill run on its own reads and validates the file directly.
- **If the file exists, validate it.** Any error **stops the run** with every error listed. Never
  fall back silently to default mode.
  - The file is not valid YAML → error.
  - When `contract:` exists: `brief` is present and readable; every listed path (`brief`,
    `requirements`, `paths.*`, `decisions.dir`, `protected`, `frozen`, `path_check`,
    `external_gates[].file`) is relative to the repo root and contains no `..`;
    `stages.prototype` ∈ {`spike`, `ui-spec`}, and `paths.prototype` is **required** when it is
    `ui-spec`; every `external_gates[].before` ∈ {`stories`, `prototype`, `specs`, `build`,
    `signoff`}; gate `id`s are unique.
  - When `review:` exists: `independence` ∈ {`off`, `warn`, `required`}.
  - Unknown keys → a warning, then ignored.
- Defaults: `stages.design` = `true`; `stages.prototype` = `spike`.
- `decisions.dir` is treated as **protected**, except for adding new Proposed records (§8, §10).
- The safety floors in `ait-conventions` always apply. Contract mode never weakens sign-off,
  required gates, waivers or the `decisions.md` sign-off record.

### 2. The brief
- `contract.brief` is the run's **specs source** (it replaces the orchestrator's "specs source"
  input).
- Never invent, rewrite or "improve" the brief. Ambiguities are questions for the human, or a new
  Proposed decision record (§8); never silent edits.

### 3. Requirements and stories
- If `requirements` is set, `ait-product-owner` **slices it into stories** written to
  `paths.stories` (default: the tracking store). Each story cites the requirement ID(s) it
  delivers and any decision record it implements, and carries testable acceptance criteria.
- **No new PRD.** If `requirements` is unset, write the stories from the brief, still with no PRD.
- If `requirements` is set but the file is missing or unreadable, stop and ask the human.
- The stories task's `spec-review` gate checks **traceability** (every story cites its source;
  every requirement in scope is covered) and **testability** (every story has verifiable
  acceptance criteria).

### 4. Flow (architecture-first)
Task kinds, in this order (each task records its `kind` in `state.json`):

| kind | owner | phase | gate(s) besides `path-check` |
|------|-------|-------|------------------------------|
| `stories` | `ait-product-owner` | plan | `spec-review` (§3) |
| `design` | `ait-product-designer` | plan | `design-review` — **only** if `stages.design` is true |
| `prototype` | `ait-product-designer` | plan | `prototype-review` — UI work only |
| `specs` | `ait-architect` | plan | `spec-review` |
| `build` | `ait-backend-dev` / `ait-frontend-dev` | build | per `ait-quality-gates` |
| `test` | `ait-qa-test` / `ait-code-reviewer` / `ait-security-rai` | test | per `ait-quality-gates` |
| `signoff` | humans | signoff | the mandatory sign-off (unchanged) |
| `deploy` | `ait-devops` | deploy | `pre-deploy` → `smoke` → `rollback-ready` |

- There is **no PRD task**. `design` and `prototype` follow the same UI-applicability rule as
  default mode (`ait-conventions` › Lifecycle DAG).
- With `stages.design: false`, no design task is scheduled; the prototype works from the brief,
  the stories and any design system already in the host repo.
- Re-decompose the `build` and `test` tasks once the `specs` tasks pass their gates.

### 5. Prototype as UI spec
- Applies when `stages.prototype: ui-spec`. With `spike` or unset, the prototype is the default
  **throwaway spike** and nothing in this section applies.
- The output folder is `paths.prototype`.
- The prototype defines canonical `data-testid` attributes on its **critical flows**.
- Once its `prototype-accepted` gate is met (§7), the prototype is **kept as the UI
  specification**: implementation reuses its `data-testid` selectors, and QA re-runs those flows
  against the build.
- Any later change to the accepted prototype — including a new `-v<N+1>` version the user
  creates — changes its digest (§13): the gate becomes **stale**, and specs written against the
  old digest are flagged for review.
- It is **never shipped** as the product; production UI is still built in `build`.

### 6. Implementation specs
- `ait-architect` writes the implementation specs to `paths.specs`, against the stories and the
  accepted prototype. Each spec notes the prototype digest it was written against, so §5 can flag
  it when that digest goes stale.
- Specs respect everything under `protected` (e.g. the host's architecture docs) and accepted
  decision records; a needed change to them is a change request (§9).
- In contract mode `ait-architect` **does not dispatch** other agents (even where its agent
  frontmatter allows it); the orchestrator does.

### 7. External gates are preconditions
- Each task records its `kind` (§4) and, for `build`, `spec`: the implementation spec it
  implements (this fills `{spec}`, §13).
- **Before dispatching** a task whose kind equals a gate's `before`, check every matching gate.
  A gate is **met** only when all of these hold:
  1. its receipt file (the gate's `file`, placeholders filled) exists;
  2. the receipt has `status: accepted` (schema: `references/config-and-receipts.md`);
  3. its `digest` equals the **current** digest (§13) of the artifact it accepts (for
     `release-acceptance`, the release candidate SHA);
  4. `decisions.md` holds the human's **confirmation** of that gate id and digest: a verbatim
     quote or reference, recorded the first time the human confirms, as for sign-off. The
     confirmation is persisted, so it survives resume.
- **Not met** → the task and its dependents are `blocked` with `blockedBy: external:<id>`, and
  **no retry is consumed**. Other ready tasks continue; the run pauses only when no task is ready.
- On **every loop iteration and every resume**, re-check blocked tasks: when the gate is met they
  return to `pending`. A **stale** gate (new digest) blocks dependent tasks again.
- The team **never writes** acceptance receipts and never edits them.
- A **phase skill run on its own** in contract mode checks the gates for its own task kind first,
  and refuses with the reason (the unmet gate id and why) if any is not met.
- External gates are preconditions, not post-task gates: they never appear in `requiredGates`.

### 8. Decisions
- If `decisions` is set, each new decision is a **new** record file in `decisions.dir` with
  status `proposed_status`.
- Specialists **never** edit existing records and never set `accepted_status`; only humans do.
- The Scribe (or the orchestrator inline in the CLI) **adds** one line to `decisions.md` per
  record: `[<id>](<path>) — <status> — <one-line summary>`.
- **Everything `decisions.md` already holds stays**: the full sign-off record, gate
  confirmations (§7) and waivers, exactly as the safety floors require.
- If `decisions` is unset, decisions go to `decisions.md` as in default mode.

### 9. Change requests
- A change to anything under `protected`, or to an **accepted** decision record, is never made
  directly. Raise it as a **new Proposed record** (§8) that states the change and its reason.
- The affected story (and its dependent tasks) is `blocked` with `blockedBy: decision:<id>`
  until a human accepts or rejects the record; **no retry is consumed**.

### 10. `path-check` gate
Added to every task's `requiredGates` in contract mode.
- **Before each dispatch**, record a baseline in the tracking store: the `HEAD` commit,
  `git status --porcelain=v1 -uall`, and a SHA-256 of every path that is changed or untracked
  at that moment.
- **After the task**, candidates = `git diff --name-only <baseline HEAD>` ∪ the untracked paths
  now ∪ the baseline's changed paths (renames: both names). Committed changes count.
- A candidate **was changed by the task** only if its current content (or absence) differs from
  its baseline content: the recorded hash for paths changed at baseline, otherwise the blob at
  `<baseline HEAD>`. Pre-existing dirty files the task left alone don't count.
- **Fail** if a task-changed path is under `frozen` (no exception), under `protected`, or in
  `decisions.dir`. The one exception: a **new** file in `decisions.dir`, not under `frozen`,
  whose status is `proposed_status`.
- If `contract.path_check` is set, run that command too; a non-zero exit fails. Both must pass.
- Specialists still add their own unit and integration tests, outside `frozen`.
- Command recipes: `references/path-check-and-digests.md`.

### 11. Deliverables
- Specialists write deliverables to `contract.paths` where set (stories, prototype, specs,
  results); the `inbox/` file keeps a short pointer to them.
- `.copilot-tracking/` stays the trace; `state.json` stays canonical for tasks and resumption.

### 12. Result
Return the standard Result block from `ait-conventions`, plus one line:
`- Contract: <rules applied; gates met or blocked>` (see Output).

### 13. Artifact identity
Acceptance binds to **content**, not to a label.
- A **file** → the SHA-256 of its bytes, lowercase hex.
- A **folder** → the SHA-256 of a canonical manifest: one line per file,
  `<path relative to the folder, with '/' separators> <file SHA-256>`, sorted by path (byte
  order), UTF-8, LF line endings, with a trailing newline. **Excluded** from the manifest: any
  file matching an `external_gates[].file` (the receipts themselves), so writing a receipt never
  changes the digest it records.
- The **release** → the commit SHA of the release candidate. The orchestrator records it in
  `state.json.signoff.artifact` as soon as Build and Test are green, **before** evaluating
  `release-acceptance`.
- Any change to the content gives a new digest, so an earlier acceptance becomes **stale**.
- Placeholders in `external_gates[].file`: `{spec}` = the file name, without extension, of the
  implementation spec a build task implements; `{version}` = the release candidate's commit SHA
  (short form allowed).

## Output
```
### Result — <task-id> · <agent>
- Status: done | blocked
- Files: <added/modified paths>
- Gate: <which gates ran + pass/fail, including path-check>
- Decisions: <key decisions or new Proposed records, or "none">
- Next: <suggested next agent/phase, or "orchestrator">
- Contract: <rules applied; gates met or blocked, e.g. "external:prototype-accepted met">
```

## Guardrails
- Never apply any of this without a `contract:` block; never fall back silently on a bad config.
- Never write, edit or "fix" acceptance receipts, the brief, the requirements, anything under
  `protected` or `frozen`, or existing decision records.
- Never set a record to `accepted_status`, and never count an agent's own message as a human
  confirmation or approval.
- The safety floors in `ait-conventions` win over any contract setting or host rule.
- Limits stay with the host (CLI session limits such as `--max-ai-credits`, a soft cap) and the
  existing retry rule. Contract mode adds none.

## References
- `references/config-and-receipts.md` — annotated `.github/ai-sdlc.yml` example, validation
  checklist, receipt schema, `decisions.md` link-line format.
- `references/path-check-and-digests.md` — commands for digests (§13) and `path-check` (§10).
