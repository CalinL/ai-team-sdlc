---
name: ait-init
description: 'Optional one-time bootstrap for a repository/workspace adopting the ai-team-sdlc plugin. Wires the plugin in (enables it declaratively, seeds a thin AGENTS.md pointer, creates and git-ignores the runtime tracking store) WITHOUT copying agents, skills, or the contract. The team already works right after plugin install because the orchestrator auto-creates the tracking store, so this only makes adoption explicit and tidy. Do not use to run the lifecycle (that is ait-sdlc-orchestrate) or to author primitives.'
---

# AI-Team SDLC — Init / Setup

You prepare a target repository so the **ai-team-sdlc** plugin's agents and skills work there
out of the box. You **wire, you do not copy**: the agents, skills, and the shared contract live in
the plugin (a single, updatable home). Copying them into the repo would fork them and break
`copilot plugin update`, so this skill only writes thin pointers and runtime scaffolding.

> **This step is optional.** The team works the moment the plugin is installed — the
> `ait-sdlc-orchestrate` skill auto-scaffolds `.copilot-tracking/` on first run, so forgetting
> `ait-init` breaks nothing. The path is simply: **install the plugin → (optional) run `ait-init`
> → the repo is an agentic SDLC workspace.** Run it to make adoption explicit: enable the plugin
> declaratively, drop an `AGENTS.md` pointer for humans, and pre-create the git-ignored tracking store.

Follow the `ait-conventions` skill for the shared contract this team operates under.

## When to use
- A user wants to adopt the AI-SDLC team in a new repo/workspace ("set this repo up", "ait-init").
- After installing the plugin, to enable it declaratively and seed the minimum scaffolding.

## When NOT to use
- To run or resume the lifecycle -> use `ait-sdlc-orchestrate` (`/product-run`).
- To edit the contract, agents, or skills -> those live in the plugin, not the consumer repo.
- To copy plugin primitives into the repo -> never do this; it forks them from updates.

## Inputs
| Input | Required | Notes |
|-------|----------|-------|
| repo root | yes | The workspace to bootstrap (default: current working directory). |
| marketplace ref | no | Defaults to `CalinL/ai-team-sdlc`. |
| overwrite AGENTS.md | no | Default **no**; never clobber an existing `AGENTS.md` without explicit consent. |

## Procedure
Perform each step idempotently — detect existing state and merge rather than overwrite.

1. **Confirm the plugin is available.** If the marketplace is not registered, tell the user to run
   `copilot plugin marketplace add CalinL/ai-team-sdlc` and
   `copilot plugin install ai-team-sdlc@ai-team-sdlc`. Do not attempt network installs silently.
2. **Enable the plugin declaratively.** Create or merge `.github/copilot/settings.json` so the
   `enabledPlugins` array contains `"ai-team-sdlc@ai-team-sdlc"` (preserve any existing entries and
   other keys). See the template below.
3. **Seed a thin `AGENTS.md` pointer** — only if `AGENTS.md` does not already exist. It must be a
   short pointer to the `ait-conventions` skill, not a copy of the contract. If `AGENTS.md` exists,
   leave it and, with consent, append a one-line note that the repo uses the plugin.
4. **Create the runtime tracking store.** Ensure `.copilot-tracking/` exists (add a `.gitkeep`) and
   add `.copilot-tracking/` to `.gitignore` if not already ignored. This directory is per-run state,
   never committed.
5. **Report** what was wired and the exact next command to start work
   (`/product-run` or "Use the ait-sdlc-orchestrate skill").

## Templates

`.github/copilot/settings.json` (merge, don't replace):
```json
{
  "enabledPlugins": ["ai-team-sdlc@ai-team-sdlc"]
}
```

Thin `AGENTS.md` pointer (write only if absent):
```markdown
# AGENTS.md

This repository uses the **ai-team-sdlc** GitHub Copilot plugin: an orchestrator plus `ait-`
specialist agents and skills that take an idea from ideation to deploy with quality gates and one
human governance sign-off.

- **Shared contract:** the `ait-conventions` skill is the single source of truth (tracking store,
  task schema, handoff contract, quality gates, resumability, sign-off).
- **Run the lifecycle:** `/product-run` (VS Code) or "Use the ait-sdlc-orchestrate skill" (CLI).
- **Single phase:** the `/product-*` commands, or invoke the matching `ait-*` skill directly.
- **Runtime state:** lives under `.copilot-tracking/<run-id>/` and is git-ignored.

Do not copy the plugin's agents or skills into this repo; update them with `copilot plugin update`.
```

`.gitignore` entry:
```
.copilot-tracking/
```

## Guardrails
- **Never** copy the plugin's agents, skills, or the contract into the target repo.
- **Never** overwrite an existing `AGENTS.md`, `.gitignore`, or `settings.json` — merge or skip.
- Keep every write minimal and reversible; report each file you create or modify.
- Do not run destructive git or filesystem operations.

## Output
```
### Result — <task-id> · ait-init
- Status: done | blocked
- Files: <created/modified paths, or "none">
- Gate: <n/a for setup, or the checks you ran>
- Decisions: <key decisions, or "none">
- Next: <e.g. "run /product-run with your spec">
```
