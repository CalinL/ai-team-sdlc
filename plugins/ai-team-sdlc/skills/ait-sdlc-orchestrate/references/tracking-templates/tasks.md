# Tasks — {{RUN_ID}}

Projection of `state.json` (canonical). Regenerate from it; do not hand‑edit out of sync.

| id | title | owner | phase | deps | acceptance | requiredGates | gateResults | status |
|----|-------|-------|-------|------|------------|---------------|-------------|--------|
| T-001 | {{TITLE}} | {{OWNER}} | {{PHASE}} | - | {{ACCEPTANCE}} | {{GATES}} | not_run | pending |

Legend:
- phase: plan | build | test | signoff | deploy (exactly one per task)
- status: pending | in_progress | blocked | done
- gateResults: not_run | passed | failed | skipped (per required gate)
