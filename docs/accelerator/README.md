# The Art of the Possible: Bring Business Ideas to Life with GitHub Copilot

**Don't just pitch the idea. Put it in their hands.**

Turn a company's public business context into two credible opportunities, then build an
interactive executive showcase for the first one. Explore a realistic workflow, reveal the
business opportunity, and let a narrated **Simulate** tour tell the story.

This Accelerator is for product teams, technical practitioners, and innovation leaders.
You describe the business intent and judge the result; GitHub Copilot does the prototyping.
No coding experience is assumed, but you remain responsible for permissions, evidence, and
what you present. The result is a prototype, not a production system.

## Start here

**Use the GitHub Copilot App or CLI.** Prefer a visual interface? The
[prerequisites](prerequisites.md#option-a-github-copilot-app) include an App setup route.
Both use the same Accelerator prompts.

**Prefer a visual guide?** [View the Accelerator on GitHub Pages](https://calinl.github.io/ai-team-sdlc/accelerator/).
It includes the full guide, copyable prompts, chapter navigation, light/dark views, and print styling.
For offline use, download [the HTML companion](index.html) and open it in a browser.
GitHub's source-file viewer does not run HTML; the Pages version does.

| Your next step | Open |
|---|---|
| Install and check the essentials | [Prerequisites](prerequisites.md) |
| Run the Accelerator, step by step or on autopilot | [Guide](guide.md) |
| Resolve setup or readiness blockers | [Troubleshooting](troubleshooting.md) |
| Create an optional PDF or PowerPoint leave-behind | [Optional outputs and next steps](optional-outputs.md) |

## The whole experience in three prompts

Paste **prompts** into Copilot. Run **terminal commands** in your terminal instead.
Replace the entire `<placeholder>`, including the angle brackets.

**Discover**

```text
Use the ait-idea skill to find 2 business use cases for <Company>
from <https://www.company.com>.
```

**Build**

```text
Use the ait-product-showcase skill to build an executive showcase prototype
from use case 01 in docs. Use its brief as the product requirements, with
its one-pager and research as narrative, brand and evidence context—not
a UI to reproduce.
```

**Refine**

```text
Make the business reveal more compelling: <what the user should understand
or be able to do>. Use the ait-product-showcase skill to refine the
existing prototype within its brief and update Simulate.
```

For the unattended chain, use the [autopilot prompt](guide.md#fast-track-one-prompt)
after completing setup. It connects the two skills without restating their workflows.

## What you will have

In **your own workspace's `docs` folder**, not this repository's documentation:

- A cited research dossier with company context, evidence classes, brand guidance, and ranked ideas.
- Two company-styled HTML one-pagers and two Markdown prototype briefs.
- One self-contained `<product>-v1.html` showcase with realistic simulated data,
  working interactions, and a Simulate tour with narration, transcript, and controls.
- Verification and review findings, with an honest **READY** or **BLOCKED** outcome.

Readiness is earned, not guaranteed by elapsed time. A workshop agenda can provide checkpoints,
but must never turn an unfinished draft into an executive-ready deliverable.

## The executive bar

The wow is a **business reveal**, not an animation: something previously slow, difficult, or
hard to see becomes understandable or actionable in the demonstration.

Before presenting, ask: **Would I stand in front of this CEO and present it myself?
Could I defend the evidence, explain what is simulated, and show why the idea matters?**

Both final showcase critics must agree. If the review budget runs out first, report the
remaining concerns and mark the showcase **BLOCKED**, not done.

## Scope and boundaries

Use public, non-personal source information and invented demo people in this Accelerator.
Do not include private documents, credentials, personal records, or internal integrations.
No publishing, committing, deployment, or production implementation is part of the core run.
PDF and PowerPoint exports are optional. New prototype versions and expanded scope are your decision.

The [ideation skill](../../plugins/ai-team-sdlc/skills/ait-idea/SKILL.md) and
[showcase skill](../../plugins/ai-team-sdlc/skills/ait-product-showcase/SKILL.md)
own the workflow and review criteria; these pages explain how to use them, not replace them.
