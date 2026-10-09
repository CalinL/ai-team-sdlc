# Get ready

[Accelerator home](README.md) | [Next: run the guide](guide.md)

**Finish setup before starting discovery.** Choose **GitHub Copilot App** for a visual
interface or **GitHub Copilot CLI** for a terminal. The Accelerator prompts and readiness
criteria are the same; installation and session controls differ.

| Setup | App | CLI |
|---|---|---|
| Install and sign in | Download the App; sign in through its window. | Install `copilot`; sign in with `/login`. |
| Team plugin | **Customize > Plugins**. | `copilot plugin` commands. |
| Browser tool | **Customize > MCP**; Node.js and a supported browser still needed. | `copilot mcp add`; same runtime/browser needs. |
| Workspace | Add a local folder under **Projects**, then run in the **local repository**. | Start `copilot` in your fresh folder. |
| Mode and model | Pickers below the prompt box. | `/model` and `/autopilot`. |

Neither route requires document skills unless you want an optional PDF or PowerPoint.

## Option A: GitHub Copilot App

### 1. Install and sign in

Download the [GitHub Copilot App](https://github.com/features/ai/github-app) and install
[Git](https://git-scm.com/downloads). Open the App, choose **Sign in to GitHub**, and
complete onboarding with your Copilot account. Organizational App policy is separate
from CLI policy; contact your administrator if access is blocked.

The local Playwright MCP server also needs [Node.js LTS](https://nodejs.org/en/download)
and a supported installed browser. PowerShell 7 and the separate CLI installation are
not requirements for this App route.

### 2. Add the team plugin

Open **Customize > Plugins**. Use the icon next to the marketplace dropdown to add
`CalinL/ai-team-sdlc`, then find **ai-team-sdlc** and select **Install**.
If already installed, confirm its version rather than installing another copy.

### 3. Add or check the browser tool

Open **Customize > MCP** and check **Installed** first. GitHub documents that skills
and MCP servers configured for your repositories or Copilot CLI are also available in
the App; verify they load rather than adding duplicate configuration.

If Playwright is missing, add a custom local MCP server. For the Windows/Edge recipe,
use command `npx` with arguments `-y @playwright/mcp@latest --browser msedge`.
This runs the public Playwright MCP package; use it only where permitted.
For other platforms, choose a supported installed browser from the Playwright reference below.

If you prefer configuring through a terminal and already have the CLI, the Playwright
command under **CLI step 2** is an alternative—not an extra App prerequisite.
Restart the session if new tools or skills do not appear.

### 4. Connect your workspace and start a session

Create a fresh folder outside the plugin repository using your file manager.
Initialize it as a Git repository by running `git init` in a terminal opened in that
folder. Git is already a prerequisite; this does not require Copilot CLI or PowerShell 7.
The repository makes ideation's default `docs` output match the showcase handoff.

In the App, use the add-project control beside **Projects**, choose
**Local folder or repository**, and select that folder.

Below the prompt field, choose execution in the **local repository**, not a new
working tree or cloud sandbox, so the documented `docs` path stays in your chosen folder.
Choose **Interactive** initially and a capable model. Run the
[shared setup check](#4-prove-the-core-path-works) in that project's agent session,
not in a general Chat.

For the fast track, select **Autopilot** from the mode picker after checking permissions;
`/autopilot` is also available. Tool auto-approval is a separate setting, not a prerequisite
to enable blindly. If permissions cannot be safely authorized, stay Interactive and use
the guided route. The CLI continuation-limit flag below is not an App setup command.

Then go to the [Accelerator guide](guide.md). The same skill prompts apply.

App references: [Quickstart](https://docs.github.com/en/copilot/get-started/quickstart-copilot-app) |
[Plugins, skills and MCP](https://docs.github.com/en/copilot/how-tos/github-copilot-app/customize-github-copilot-app) |
[Session location, mode and model](https://docs.github.com/en/copilot/how-tos/github-copilot-app/agent-sessions).

## Option B: GitHub Copilot CLI

## 1. Check access and install the essentials

You need a GitHub account with access to Copilot CLI, permission to use the required tools,
and internet access for public research. Organizational policy and usage limits can affect
availability. Check the [official CLI quickstart](https://docs.github.com/en/copilot/get-started/cli-quickstart)
for current requirements and installation options.

The Windows recipe uses **PowerShell 7**, **Git**, **Node.js LTS**, and an installed
**Microsoft Edge** browser. Git is used to create your local working repository;
Node.js runs the Playwright MCP server. Python and document-generation plugins are not
core prerequisites.

**Windows terminal commands** - install missing tools only:

```powershell
winget install --id Microsoft.PowerShell -e
winget install --id Git.Git -e
winget install --id OpenJS.NodeJS.LTS -e
winget install --id GitHub.Copilot -e
```

Run one command at a time and resolve any errors. If installations are restricted, use your
approved installation route rather than bypassing policy.

Close and reopen Terminal, start **PowerShell 7** with `pwsh`, then check:

```powershell
copilot --version
git --version
node --version
```

On macOS or Linux, use the official quickstart's platform instructions. Do not paste the
Windows commands into a different shell.

Start `copilot`, complete sign-in when prompted (or use `/login`), and exit with `/exit`
before configuring the tools below.

## 2. Install the team and browser tool

**Terminal commands:**

```powershell
copilot plugin marketplace add CalinL/ai-team-sdlc
copilot plugin install ai-team-sdlc@ai-team-sdlc
```

Already installed? Update rather than reinstall:

```powershell
copilot plugin update ai-team-sdlc@ai-team-sdlc
```

For the Windows recipe, add Playwright MCP using Edge:

```powershell
copilot mcp add playwright -- npx -y @playwright/mcp@latest --browser msedge
```

This command downloads and runs the public Playwright MCP package. Use it only where permitted.
If an MCP server named `playwright` already exists, inspect its configuration using `/mcp`
rather than creating a conflicting entry.

Other platforms can use a supported installed browser; follow the
[Playwright MCP configuration](https://github.com/microsoft/playwright-mcp#browser-configuration).
The browser tool and web research are separate checks: opening a page does not prove that
research is available.

## 3. Create a fresh workspace

Create an empty folder **outside this plugin repository** and outside sensitive working folders.
The following example creates a uniquely named local workspace; it does not clone the plugin.

**Windows PowerShell commands:**

```powershell
$workspace = Join-Path $HOME ("art-of-the-possible-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Path $workspace -ErrorAction Stop
Set-Location $workspace
git init
copilot
```

Confirm that Copilot is working in this folder. All generated files go in its `docs` subfolder.
`ait-init` is not required for direct skill use; do not configure adoption unless you intend to.

**A folder is not a sandbox.** For the guided route, leave ordinary permissions in place and
approve only the access needed for the task. Inspect `/permissions` and, where supported,
`/sandbox`. Do not connect private-data tools. The fast track has a separate permission
decision, explained below; broad permission approval is never an automatic setup step.

## 4. Prove the core path works

**Shared check:** CLI users paste into the active CLI session; App users paste into
the connected project's **Interactive** agent session. No different prompt is needed.

Paste this **prompt into Copilot** before starting the Accelerator:
Replace `<https://www.company.com>` with your target company's actual public site.

```text
Check setup only: confirm ait-idea and ait-product-showcase load, fetch
<https://www.company.com>, and use Playwright MCP to open both that page
and a temporary local HTML file. Remove your temporary file afterward.
Report passed, failed or unavailable checks and whether independent
review subagents are available. Do not start discovery or a showcase.
```

**Ready to start when:** both skills load, research works, the MCP browser opens both web
and local HTML, and you know which review capabilities are available.

Two independent reviewers are required for the unattended showcase path. Ideation permits
its documented, disclosed self-review fallback when reviewers are unavailable, but that
does not silently satisfy the showcase's independent-review requirement.

If a core check fails, use [troubleshooting](troubleshooting.md) before spending time on a build.

## Choose the mode and model

**App:** use the model and mode pickers below the prompt field.
**CLI:** use `/model`; for the fast track, enable `/autopilot`.
No particular model version is required. Research, builds, and repeated reviews consume
your allowance. Check `/usage` and applicable limits before a long run.

**The following permission and continuation details describe the CLI.** Autopilot controls continuation;
it does not itself grant all permissions. When entering the mode, the CLI may ask whether
to enable all permissions, use manual approval, or cancel. In autopilot, manual approval
**automatically denies requests that still need approval** rather than pausing for you to
approve them. The chain can therefore become blocked.

For an unattended run, review the official permission guidance and deliberately decide
whether broad permissions are acceptable in your environment. Consider supported sandboxing
first and verify that browser and workspace access still work inside it. Never assume the
workspace folder limits access. If you cannot safely authorize the required actions, cancel
autopilot and use the guided interactive route instead.

Autopilot can also pause at its continuation limit (currently five continuations by default).
The `--max-autopilot-continues` launch option changes that limit; check current CLI help before
adjusting it. Continuation limits are separate from the skills' three-round review budgets.
Do not reset a review budget to resume a paused session. Stop unexpected work with **Esc twice** in the CLI.

## Other interfaces

- **VS Code Copilot:** use the installed skills or `/product-idea` and `/product-showcase`
  wrappers when available. Confirm installation and browser configuration in VS Code;
  the CLI's MCP setup is not a promise that another interface is configured.
- **GitHub Copilot App:** use the App route above; no separate Accelerator prompts are needed.
- **Another agent host:** the ideation skill is self-contained and can be pasted in.
  Transfer its dossier, selected brief, and one-pager together into the showcase workspace.
  The full showcase still requires its companion skills, assets, browser tooling, and review capability.

## Setup references

- [App download](https://github.com/features/ai/github-app)
- [App quickstart](https://docs.github.com/en/copilot/get-started/quickstart-copilot-app)
- [App customization](https://docs.github.com/en/copilot/how-tos/github-copilot-app/customize-github-copilot-app)
- [App session controls](https://docs.github.com/en/copilot/how-tos/github-copilot-app/agent-sessions)
- [App slash commands](https://docs.github.com/en/copilot/reference/github-copilot-app-reference/slash-commands)
- [CLI quickstart](https://docs.github.com/en/copilot/get-started/cli-quickstart)
- [Plugin installation](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-finding-installing)
- [MCP configuration](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)
- [Autopilot and permissions](https://docs.github.com/en/copilot/concepts/agents/copilot-cli/autopilot)
- [Tool permissions](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/allowing-tools)
