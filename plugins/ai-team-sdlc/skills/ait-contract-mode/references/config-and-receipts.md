# Contract mode — configuration and receipts

Reference for `ait-contract-mode` §1, §7 and §8. The rules live in `SKILL.md`; this file holds the
long-form example and schemas.

## `.github/ai-sdlc.yml` (annotated example)
All paths are the host repo's choice and are relative to the repo root.

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

## Validation checklist (§1)
Run every check and report **all** errors together; any error stops the run.

| # | Check | Applies when |
|---|-------|--------------|
| 1 | The file parses as YAML | the file exists |
| 2 | `brief` is present and readable | `contract:` exists |
| 3 | Every listed path is relative to the repo root and has no `..` (`brief`, `requirements`, `paths.*`, `decisions.dir`, `protected[]`, `frozen[]`, `path_check`, `external_gates[].file`) | `contract:` exists |
| 4 | `stages.prototype` ∈ {`spike`, `ui-spec`} | it is set |
| 5 | `paths.prototype` is set (a new run defaults it to `specs/ui/`) | `stages.prototype: ui-spec` on a resumed run started on 1.1.0 |
| 5b | `{feature}` appears only in `paths.stories`, and that path resolves under the effective `paths.specs` | `paths.stories` contains `{feature}` |
| 6 | every `external_gates[].before` ∈ {`stories`, `prototype`, `specs`, `build`, `signoff`} | gates are listed |
| 7 | `external_gates[].id` values are unique | gates are listed |
| 8 | `review.independence` ∈ {`off`, `warn`, `required`} | `review:` exists |
| — | Unknown keys → **warning** only, then ignored | always |

Example error report:
```
.github/ai-sdlc.yml is invalid — the run is stopped (no fallback to default mode):
- contract.brief: missing
- contract.external_gates[1].before: "deploy" is not one of stories | prototype | specs | build | signoff
- contract.paths.stories: "stories/{feature}.md" uses {feature} but does not resolve under contract.paths.specs (specs/features/)
```

## Acceptance receipt schema (§7)
Written by a **human**, never by the team. One file per gate, at the gate's `file` path with the
placeholders filled (`{spec}`, `{version}`: see `SKILL.md` §13).

```markdown
---
status: accepted            # accepted | rejected
accepted_by: <name>         # a human
accepted_at: <ISO date>
artifact: <path accepted>
digest: <digest of the accepted artifact, computed as in SKILL.md §13>
---
<free text: conditions, notes>
```

A gate is met only when the receipt exists, says `status: accepted`, its `digest` equals the
artifact's **current** digest, **and** `delivery/approvals.md` holds the human's confirmation of that gate
id and digest. Record that confirmation the first time the human gives it, for example:

```markdown
### External gate confirmed — prototype-accepted
- Gate: prototype-accepted · Artifact: specs/ui/ · Digest: <sha256>
- Confirmed by: <human name> · <ISO timestamp>
- Quote: "<verbatim confirmation from the human turn>"
```

## `decisions.md` link lines (§8; historical, 1.1.0)
Under 1.1.0, one line per record in `decisions.dir` was added to the run's `decisions.md`. From
1.1.1 on, nothing is appended: a resumed 1.1.0 run keeps that file read-only, and a run started on
1.1.1 has no `decisions.md`. The format, for reading older runs:

```
[ADR-012](architecture/adr/ADR-012-cache-layer.md) — Proposed — Add a read-through cache for catalog queries
```

## `state.json` fields used in contract mode
- Run: `"mode": "contract"`; `signoff.artifact` = the release candidate commit SHA (§13).
- Task: `kind` (§4); `spec` for `build` tasks (§7); `blockedBy` (`external:<id>` or
  `decision:<id>`) while blocked (§7, §9); `path-check` in `requiredGates` (§10).
- Older runs and default-mode runs without these fields still resume.
