# Tests

Rerunnable checks for the ai-team-sdlc plugin. Run the free tiers on every change; run the agent
probes when you change a skill or agent; run the end-to-end lifecycles before a release.

| Tier | What it proves | Cost | Where it runs |
|---|---|---|---|
| 1. Static (`static/`) | Plugin files are well formed and match the change specs: front matter, agent policy, credit headers, vendored skills byte-identical, skill size, layout table = spec, no 1.1.0 output paths, approvals rules, 13 contract-mode blocks, relative links, versions and counts, JSON. A mutation self-test proves each check can fail. | free, seconds | CI + local |
| 2. Recipes (`recipes/`) | The path-check and folder-digest recipes, extracted from `skills/ait-contract-mode/references/path-check-and-digests.md`, give the expected verdict on 27 fixtures in bash, PowerShell 7 and Windows PowerShell 5.1, and the same digests as a Python reference. | free, ~2 min | CI (Linux + Windows) + local |
| 3. Agent probes (`agents/`) | Agents behave as the skills say, on small seeded repos: artifact placement (including a weak model), host rules and explicit folders, version series, Scribe writes only human records, sign-off validity against the release candidate, 1.1.0 carry-over, contract validation and activation, default mode applies no contract rule; from 1.1.2, branches and pull requests (cases carry a `Since` version and are skipped against older plugins). | ~300 AI credits for one run of every case (measured: 266 for 13 cases; the 5-run weak cases ~60 each) | local, Copilot CLI |
| 4. End to end (`e2e/`) | A whole lifecycle in a scratch repo: default mode (idea → sign-off → deploy) and contract mode (brief → conformance → build → release acceptance → sign-off → deploy), with scripted human steps; asserts the layout, the approval rules, the tracking store and a fresh clone. | measured: default ≈ 360 credits / 20 min; contract ≈ 560 credits / 40 min | local, Copilot CLI |

## Running

Requirements: Python 3.9+ with PyYAML, git, bash (Git Bash on Windows), PowerShell 7. Tiers 3–4 also
need the [Copilot CLI](https://docs.github.com/en/copilot/get-started/cli-quickstart) signed in, and Node.js
for the E2E service's tests.

```powershell
pwsh tests/run.ps1                                   # tiers 1–2 + agent-harness dry run (free)
pwsh tests/run.ps1 -Tier agents                      # every agent probe, default runs
pwsh tests/run.ps1 -Tier agents -Case layout-* -Runs 1
pwsh tests/agents/run_agents.ps1 -List               # cases, models, runs, thresholds
pwsh tests/run.ps1 -Tier e2e -E2E default            # or contract, both
```

```bash
bash tests/run.sh                                    # tiers 1–2 (+ dry run when pwsh is present)
```

Output goes to `tests/out/` (git-ignored): extracted recipes, transcripts (`run-<n>.log`), per-run
grades and a `summary.md` or `report.md`. Scratch repos live in the system temp folder, outside this
repository, so its own `AGENTS.md` never leaks into a probe.

The probes run the plugin **from this working tree** (`copilot --plugin-dir plugins/ai-team-sdlc`);
set `AIT_PLUGIN_DIR` to test another checkout's `plugins/ai-team-sdlc` (for example a release worktree).
If the plugin is also installed and enabled, the harness disables it for the session and re-enables it
afterwards; only one session can do this at a time, and a session killed mid-run is repaired by the next
one (a marker file in the temp folder records that the tests disabled it).

**Probes run model-driven commands.** They pass `--allow-all-tools` (not `--allow-all-paths`), so file
tools stay in the scratch repo, but shell commands are not sandboxed. Run tiers 3–4 on a development
machine, a Codespace or a disposable VM, not on a machine holding secrets or production access.

## How the probes are graded

Each case seeds a scratch git repo, runs one prompt (optionally as a named agent), then grades the
files, git state, `state.json` and transcript it left. Grades are on outcomes (where files landed,
what was committed, the sign-off status), not on wording. Weak-model cases run 5 times and pass at
4 of 5, as the change specs require; the others run once by default (raise with `-Runs`).
`-DryRun` seeds and grades every case without calling a model: every case must fail, which proves
no case passes when nothing is done (CI runs this).

To add a case, add a hashtable to a file in `agents/cases/` with `Name`, `Covers` (the spec item),
`Model`, `Runs`, `Pass`, optional `Agent`, `Files` (seed), `Setup`, then `Prompt` and `Check`
(returns failure messages; helpers in `agents/Harness.psm1`). Run it with `-DryRun` first.

## What still needs a person in VS Code

The CLI covers tiers 1–4. VS Code surfaces load the same files but can't be scripted here; after a
change to agents, prompts or skill front matter, check by hand on **VS Code (Local)** and **VS Code
(Copilot harness)**:

- [ ] Every agent appears in the agent picker and loads without a front-matter error.
- [ ] Every `/product-*` prompt runs and routes to its skill.
- [ ] Handoff buttons between agents appear as before.
- [ ] `/product-run` on a tiny idea reaches the sign-off pause, writing to the 1.1.1 layout.
- [ ] In a repo with `.github/ai-sdlc.yml` (contract block), the orchestrator reports contract mode.
