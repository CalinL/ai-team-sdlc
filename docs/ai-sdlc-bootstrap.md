# Build a Reusable AI SDLC System — Bootstrap Brief

> One-time brief. Paste this into an agent (VS Code Copilot or Copilot CLI) once to research, design, and scaffold the SDLC system. After the team exists, you won't need this again — you'll invoke the generated orchestrator instead.

Design and (after approval) scaffold a **reusable, spec-agnostic agentic SDLC system**: a master orchestrator plus a team of specialist agents, skills, and instructions. The system is the deliverable — once built, a user can later point it at *any* specs/PRDs and say "implement all this," and it decomposes the work into autonomous tasks, executes them end-to-end, resumes from where it left off if a run fails, and reports `DONE`.

This brief does **not** implement a specific feature. It builds the machine that implements features. Keep it simple and portable: the generated system must run both in the VS Code Copilot agent and the Copilot CLI, so prefer portable Markdown/agent conventions over IDE-specific wiring.

## Input (optional)

- **context** — optional target stack, repo conventions, or install location. If omitted, target this repo's `.github/` folder and infer conventions from the codebase.

## Required Phases

Do these in order. Do not create or modify any files before Phase 3 approval.

### Phase 1 — Research (read-only)

Deep-dive proven agentic SDLC patterns. Consult these sources and extract concrete, reusable building blocks (orchestrator loops, task decomposition, tracking/checkpoint state, specialist roles, quality gates, human-in-the-loop gates):

- https://github.com/githubabcs/gh-abcs-admin/blob/main/docs/20-governed-ai-sdlc-plan.md#5-the-internal-ai-sdlc-agent-team-catalog
- 
- [Anthropic skills](https://github.com/anthropics/skills)
- [Microsoft skills](https://github.com/microsoft/skills)
- [Microsoft hve-core](https://github.com/microsoft/hve-core)
- [GitHub awesome-copilot](https://github.com/github/awesome-copilot)
- [bradygaster/squad](https://github.com/bradygaster/squad)
- [Microsoft apm](https://github.com/microsoft/apm)
- [dotnet skills](https://github.com/dotnet/skills)

Also summarize what large engineering orgs do for autonomous spec-to-code. Extract 5–8 patterns; stop once the findings cover every component below. Output a short table: pattern → source → which component it maps to.

### Phase 2 — System Design Proposal (no files yet)

Propose the reusable system as a small, concrete set of artifacts:

1. Master Orchestrator — the reusable entry point. Given any specs later, it decomposes them into ordered, verifiable tasks, dispatches each to the right specialist, tracks progress, and reports `DONE` only when every task passes its gate.
2. Specialist agent team — the minimal roster (product designer - spec -> prototype, tech lead/architect, product owner, Scribe, Backend Dev, Frontend Dev, DevOps latform/IaC, QA, Code Reviewer/Critic, Security/RAI, and more) with clear ownership, hand-offs, and how the orchestrator invokes them (portable across VS Code and CLI).
3. Tracking / resumability — how a run records progress so any model can stop and continue without redoing finished work. Define the concrete schema and location during implementation (Phase 4), informed by the research; in Phase 2 just state the approach.
4. Task decomposition format — the template that turns a spec/PRD into atomic tasks with dependencies and acceptance criteria.
5. Quality gates — reusable build/test/review checks that must pass before a task is complete.
6. Supporting skills / instructions — shared conventions each specialist references, to avoid duplication.

Present an architecture overview, a component list with proposed file paths and types, the reuse flow (point at specs → decompose → execute → verify → `DONE`), and the resume flow (rerun → read tracking state → continue).

### Phase 3 — Confirmation Gate

Present the proposed file tree and ask an explicit **approve / trim / adjust** question, then **end your turn**. Create no files until the user replies affirmatively. On "trim" or "adjust", return to Phase 2 and re-present.

### Phase 4 — Scaffold the System (only after approval)

Create the approved artifacts following the `agent-customization` guidelines:

- Choose the right primitive for each component (agent / skill / prompt / instructions) at the correct location; keep each artifact single-purpose and reusable across projects.
- Wire the orchestrator to accept an arbitrary specs source at invocation time, read/write the tracking state, dispatch to specialists, and enforce quality gates — using portable conventions that work in both VS Code and the Copilot CLI.
- If a system already exists, don't overwrite without confirmation; create only what's missing.
- Add a short usage doc: how to run the system on real specs, and how a failed run resumes.

Finish by summarizing what was created, how to run it on future specs, and how resume-on-failure works.

## Constraints

- The output is a **reusable, spec-agnostic system**, not an implementation of any one spec.
- Keep it simple. Don't over-engineer — the minimal roster and the smallest set of artifacts that work.
- Portable by default: works in VS Code Copilot and Copilot CLI; avoid IDE-locked mechanisms.
- Follow the `agent-customization` skill; reference shared instructions instead of duplicating them.
- Do not hardcode secrets. Favor small, verifiable, resumable steps over one large uninterruptible run.
- Never create files before Phase 3 approval.
