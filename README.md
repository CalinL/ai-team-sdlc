# AI‑Team SDLC — Agentic Software Delivery System

A reusable, spec‑agnostic **agentic SDLC**: a master orchestrator turns any product idea or
spec into shipped software by decomposing the work into verifiable tasks, dispatching each to
the right specialist AI agent, enforcing quality gates, keeping a resumable record of progress,
and reporting `DONE` only when every task passes its gate — with one human governance sign‑off.

It is **portable** across VS Code Copilot and the Copilot CLI. The reusable logic lives in
Skills (`.github/skills/*/SKILL.md`) and `AGENTS.md`; the `.github/agents/*` personas and
`.github/prompts/*` commands are the entry points.

## The lifecycle

```
ideate → prototype (UI only) → PRD → spec → implement → test (QA + critic + security)
       → human sign‑off → deploy
```

Every stage is owned by an AI agent (namespaced `ait-`) with humans in the loop, and a single
mandatory human governance sign‑off before deploy.

## Commands (phases → skills)

| Command | Skill | Specialist agent |
|---|---|---|
| `/product-design` | `ait-product-design` | Product Designer |
| `/product-prototype` | `ait-product-prototype` | Product Designer |
| `/product-specs` | `ait-tech-specs` | Product Owner, Architect |
| `/product-implement` | `ait-implementation` | Backend / Frontend Dev |
| `/product-qa` | `ait-qa-validation` | QA / Test |
| `/product-review` | `ait-review-critic` | Code Reviewer / Critic |
| `/product-security` | `ait-security` | Security / RAI |
| `/product-deploy` | `ait-deploy` | DevOps |
| `/product-run` | `ait-sdlc-orchestrate` | Orchestrator + Scribe |

## Running

**Copilot CLI**
```
copilot -p "Use the ait-sdlc-orchestrate skill. Specs: ./specs/. Run the full SDLC and report DONE."
copilot -p "Use the ait-product-design skill to prototype the feature in ./docs/..."
```

## Repo layout

| Path | What |
|---|---|
| `.github/skills/` | Portable skills (source of truth for both VS Code + CLI) |
| `.github/agents/` | Specialist agent personas |
| `.github/prompts/` | `/product-*` slash commands |
| `.github/instructions/` | Shared AI‑SDLC conventions |
| `AGENTS.md` | Full shared contract (tracking store, gates, sign‑off, resumability) |
| `docs/` | Design, usage, bootstrap docs |
| `docs/demo/ai-sdlc-lifecycle.html` | Self‑contained animated executive demo |
| `docs/demo/ai-sdlc-lifecycle-poster.png` | High‑resolution poster export of the demo |

See `docs/ai-sdlc-design.md` for the full design and diagrams, and `docs/ai-sdlc-usage.md`
for command usage.
