---
name: web-artifacts-builder
description: Suite of tools for creating elaborate, multi-component self-contained HTML artifacts using modern frontend web technologies (React, Tailwind CSS, shadcn/ui). Use for complex artifacts requiring state management, routing, or shadcn/ui components - not for simple single-file HTML/JSX artifacts.
license: Complete terms in LICENSE.txt
---

# Web Artifacts Builder

> **AI-SDLC scope — prototype/spike only.** In this system this skill builds a **throwaway
> clickable prototype** during the **plan/prototype** stage — not the production build.
> Production UI is owned by the `ait-implementation` skill (`ait-frontend-dev`) and is written against
> the target repo's real stack per the tech spec. Never ship a bundled artifact as the product.
> Vendored from Anthropic's `web-artifacts-builder` skill (Apache-2.0, see `LICENSE.txt`).
>
> **Windows / CLI portability:** the `scripts/*.sh` helpers require a POSIX shell
> (Git Bash or WSL), Node 18+, and **`pnpm`** (the init script installs it via `npm i -g pnpm`
> if missing). Invoke them from the skill directory, e.g. `bash .github/skills/web-artifacts-builder/scripts/init-artifact.sh <name>`.
> **This Windows host has Node but no `bash`/`pnpm`**, so run a quick preflight first
> (`bash --version`, `pnpm --version`). If either is missing, either use the equivalent **npm**
> commands in PowerShell (`npm create vite@latest <name> -- --template react-ts`, then
> `npm install`, `npm run build`) or treat the stack (React + TS + Vite + Tailwind + shadcn/ui)
> as guidance and scaffold manually. Always verify the prototype with the `ait-prototype-testing` skill.

To build powerful frontend web artifacts, follow these steps:
1. Initialize the frontend repo using `scripts/init-artifact.sh`
2. Develop your artifact by editing the generated code
3. Bundle all code into a single HTML file using `scripts/bundle-artifact.sh`
4. Display artifact to user
5. (Optional) Test the artifact

**Stack**: React 18 + TypeScript + Vite + Parcel (bundling) + Tailwind CSS + shadcn/ui

## Design & Style Guidelines

VERY IMPORTANT: To avoid what is often referred to as "AI slop", avoid using excessive centered layouts, purple gradients, uniform rounded corners, and Inter font.

## Quick Start

### Step 1: Initialize Project

Run the initialization script to create a new React project:
```bash
bash scripts/init-artifact.sh <project-name>
cd <project-name>
```

This creates a fully configured project with:
- ✅ React + TypeScript (via Vite)
- ✅ Tailwind CSS 3.4.1 with shadcn/ui theming system
- ✅ Path aliases (`@/`) configured
- ✅ 40+ shadcn/ui components pre-installed
- ✅ All Radix UI dependencies included
- ✅ Parcel configured for bundling (via .parcelrc)
- ✅ Node 18+ compatibility (auto-detects and pins Vite version)

### Step 2: Develop Your Artifact

To build the artifact, edit the generated files. See **Common Development Tasks** below for guidance.

### Step 3: Bundle to Single HTML File

To bundle the React app into a single HTML artifact:
```bash
bash scripts/bundle-artifact.sh
```

This creates `bundle.html` - a self-contained artifact with all JavaScript, CSS, and dependencies inlined. This file can be opened directly in a browser or shared with the user as a prototype preview.

**Requirements**: Your project must have an `index.html` in the root directory.

**What the script does**:
- Installs bundling dependencies (parcel, @parcel/config-default, parcel-resolver-tspaths, html-inline)
- Creates `.parcelrc` config with path alias support
- Builds with Parcel (no source maps)
- Inlines all assets into single HTML using html-inline

### Step 4: Share Artifact with User

Finally, share the bundled HTML file in conversation with the user so they can view it as an artifact.

### Step 5: Testing/Visualizing the Artifact

**Optional for standalone artifact creation, mandatory under `ait-product-prototype`.** When this skill
is invoked as part of the AI-SDLC `ait-product-prototype` stage, the prototype **must** be verified with
the **`ait-prototype-testing`** skill before the `prototype-review` gate can pass — do not skip it.

For standalone one-off artifacts, testing is optional: to visualize/verify, use the
**`ait-prototype-testing`** skill (Playwright MCP). In that case, avoid testing upfront as it adds
latency between the request and the finished artifact; test later, after presenting, if requested or
if issues arise.

## Reference

- **shadcn/ui components**: https://ui.shadcn.com/docs/components