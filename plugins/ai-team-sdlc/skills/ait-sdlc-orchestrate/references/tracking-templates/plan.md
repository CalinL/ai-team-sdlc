# Plan — {{RUN_ID}}

Spec: {{SPEC_SOURCE}}
Created: {{DATE}}

Resumability: `state.json` is canonical; this file is a human‑readable projection of it.
`[x]` = done, `[ ]` = pending. On resume, skip every `[x]` and continue at the first `[ ]` whose
deps are done. When this file and `state.json` disagree, `state.json` wins.

## Plan
- [ ] Research & decompose spec into tasks

## Build
- [ ] {{TASK}}

## Test
- [ ] {{TASK}}

## Sign‑off
- [ ] Human sign‑off (Product Owner + Security + Tech Lead) — derived from `state.json.signoff.status == approved`

## Deploy
- [ ] {{TASK}}
