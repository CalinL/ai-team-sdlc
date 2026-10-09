# When something blocks progress

[Accelerator home](README.md) | [Return to the guide](guide.md)

**Keep the standard, change the plan.** A useful draft is not automatically a verified showcase.
Do not bypass policy, fabricate evidence, or silently substitute tooling to finish.

| What you see | What to do |
|---|---|
| A CLI setup command is not found | Reopen the terminal after installation and verify each tool separately. On Windows, run CLI commands in PowerShell 7. App users do not need the separate CLI or PowerShell 7; check Git and Node.js, then restart the App if needed. |
| Installation or access denied | Follow your approved device/organization process. Close relevant Copilot sessions before retrying a plugin update if files are in use; do not uninstall working components reflexively. |
| App access blocked but CLI works | App and CLI policies are separate. Ask your administrator about App access; switching interfaces is not a policy bypass. |
| App cannot see a skill or browser tool | Check **Customize > Plugins / Skills / MCP**, restart the session and run the shared setup check. Confirm existing configuration before adding duplicates. |
| App outputs are not in the selected folder | Check the session's execution location. A working tree or cloud sandbox has a different workspace; use the local repository route in prerequisites for the documented paths. |
| A skill is missing | CLI: inspect `/skills` and `/plugin`. App: check **Customize > Plugins / Skills**. Update the team plugin and restart the session. Confirm that both named skills load before research. |
| Public research cannot fetch the site | Report the limitation. Supply public-safe source excerpts with source references, or choose an accessible public source. Never cite from memory. |
| Research is NOT READY | Read the open findings. Fix them within ideation's remaining budget. Do not pass an incomplete brief into showcase. |
| Playwright MCP is unavailable | Check Node.js, permissions, browser installation and allowed server policy. CLI: inspect `/mcp`. App: check **Customize > MCP**. Do not replace it silently with a Python browser runner. |
| Web page opens but local HTML does not | Check the MCP server's local-file access options, tool permissions and path restrictions; see the configuration reference below. Retry the temporary-file smoke test. |
| Browser verification cannot run | Keep the showcase BLOCKED. Manual clicks can improve a draft but cannot silently pass the required browser gate. |
| Review subagents are unavailable | Report ideation's self-review if used. The unattended showcase remains BLOCKED; human review/waiver requires explicit user action under the skill contract. |
| Model or usage allowance is exhausted | Inspect `/usage` and applicable limits. Save the exact source/output paths and findings; resume with the existing artifact when access is restored. Do not start a new version automatically. |
| CLI autopilot denies tools instead of asking | Manual approval in CLI autopilot auto-denies requests still requiring approval. Reassess authorization safely, or switch to the guided interactive route. Do not grant all permissions reflexively. |
| CLI autopilot reaches its continuation limit | Check progress and the `--max-autopilot-continues` launch option in current CLI help, then resume only as appropriate. This limit is not the review-round budget; never reset that budget to continue. |
| The chain appears stalled | Request a progress checkpoint in the active session. In CLI, also inspect `/tasks`. Do not launch duplicate builds. Use your interface's interrupt control for unexpected work (Esc twice in CLI). |
| Files are hard to find | Ask for absolute source and output paths. Confirm that you are in your fresh workspace, not the plugin repository. |
| The UI looks like the one-pager | Clarify generate path: the brief defines product screens; the one-pager is narrative/brand reference, not a visual reproduction target. |
| Simulate is silent | Start with a user click, check audio output and browser voices. Test transcript/manual controls. Ask for a graceful fallback; do not depend on one exact voice being installed. |
| Simulate or a critical click breaks | Report the screen, action and expected result. Fix it, repeat browser checks and final peer review within the remaining budget. |
| A review asks to remove the main reveal | Fix weak evidence or execution without losing the useful business idea. Scope changes are user decisions, not automatic reviewer instructions. |
| Three showcase rounds are spent | Report BLOCKED with outstanding findings. Do not reset the budget or turn an incomplete draft into a "happy" completion. |
| Presentation time is near | Request an honest readiness checkpoint. Present only if the criteria pass; otherwise explain draft status or postpone. |

## A useful help prompt

```text
I expected <result>, but <observed behavior> happened at <step/file>.
Diagnose the cause using the existing tooling and show me the smallest fix.
Tell me which readiness checks this affects. Do not silently skip them.
```

Copy the error text, but remove credentials or personal information before sharing it.

## References

- [Playwright MCP browser and file-access configuration](https://github.com/microsoft/playwright-mcp)
- [GitHub MCP setup](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers)
- [Tool permissions](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/allowing-tools)
- [Showcase contract and blocked outcomes](../../plugins/ai-team-sdlc/skills/ait-product-showcase/SKILL.md)
