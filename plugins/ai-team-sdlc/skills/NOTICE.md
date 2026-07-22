# Attribution — Vendored Skills

Some skills in this directory are vendored (copied) or adapted from Anthropic's
**agent-skills** collection (upstream: <https://github.com/anthropics/skills>, `document-skills/skills/`)
and are redistributed under the **Apache License 2.0**. Each vendored skill keeps its upstream
`LICENSE.txt`. This file records attribution as required by the license.

| Local skill | Upstream skill | Upstream path | License | Modification |
|-------------|----------------|---------------|---------|--------------|
| `frontend-design` | `frontend-design` | `document-skills/skills/frontend-design` | Apache-2.0 | Vendored as-is. |
| `theme-factory` | `theme-factory` | `document-skills/skills/theme-factory` | Apache-2.0 | Vendored as-is. |
| `web-artifacts-builder` | `web-artifacts-builder` | `document-skills/skills/web-artifacts-builder` | Apache-2.0 | Vendored; added an AI-SDLC "prototype-only" scope header, a Windows/CLI portability note (npm/pnpm), Copilot-neutral wording, and pointed its test step at the `ait-prototype-testing` skill. |
| `ait-prototype-testing` | `webapp-testing` | `document-skills/skills/webapp-testing` | Apache-2.0 | Repurposed: rewritten to use the Playwright MCP instead of bundled Python Playwright scripts, and re-scoped to design-phase prototype verification. Retains the upstream `LICENSE.txt` for attribution. |

The remaining skills in this directory are original to the AI-SDLC system and licensed **MIT**.

Apache-2.0 requires preserving copyright/license notices and stating changes; the table above
documents the changes made to each vendored skill.
