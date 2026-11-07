# Contract mode — configuration and receipts

Reference for `ait-contract-mode` §1, §7 and §8. The rules live in `SKILL.md`; this file holds the
long-form example and schemas.

## `.github/ai-sdlc.yml` (annotated example)
All paths are the host repo's choice and are relative to the repo root.

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

## Validation checklist (§1)
Run every check and report **all** errors together; any error stops the run.

| # | Check | Applies when |
|---|-------|--------------|
| 1 | The file parses as YAML | the file exists |
| 2 | `brief` is present and readable | `contract:` exists |
| 3 | Every listed path is relative to the repo root and has no `..` (`brief`, `requirements`, `paths.*`, `decisions.dir`, `protected[]`, `frozen[]`, `path_check`, `external_gates[].file`) | `contract:` exists |
| 4 | `stages.prototype` ∈ {`spike`, `ui-spec`} | it is set |
| 5 | `paths.prototype` is set | `stages.prototype: ui-spec` |
| 6 | every `external_gates[].before` ∈ {`stories`, `prototype`, `specs`, `build`, `signoff`} | gates are listed |
| 7 | `external_gates[].id` values are unique | gates are listed |
| 8 | `review.independence` ∈ {`off`, `warn`, `required`} | `review:` exists |
| — | Unknown keys → **warning** only, then ignored | always |

Example error report:
```
.github/ai-sdlc.yml is invalid — the run is stopped (no fallback to default mode):
- contract.brief: missing
- contract.external_gates[1].before: "deploy" is not one of stories | prototype | specs | build | signoff
- contract.paths.prototype: required when contract.stages.prototype is ui-spec
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
artifact's **current** digest, **and** `decisions.md` holds the human's confirmation of that gate
id and digest. Record that confirmation the first time the human gives it, for example:

```markdown
### External gate confirmed — prototype-accepted
- Gate: prototype-accepted · Artifact: docs/delivery/prototype/ · Digest: <sha256>
- Confirmed by: <human name> · <ISO timestamp>
- Quote: "<verbatim confirmation from the human turn>"
```

## `decisions.md` link lines (§8)
When `contract.decisions` is set, add one line per record in `decisions.dir`, without removing
anything already in `decisions.md`:

```
[ADR-012](docs/adr/ADR-012-cache-layer.md) — Proposed — Add a read-through cache for catalog queries
```

## `state.json` fields used in contract mode
- Run: `"mode": "contract"`; `signoff.artifact` = the release candidate commit SHA (§13).
- Task: `kind` (§4); `spec` for `build` tasks (§7); `blockedBy` (`external:<id>` or
  `decision:<id>`) while blocked (§7, §9); `path-check` in `requiredGates` (§10).
- Older runs and default-mode runs without these fields still resume.
