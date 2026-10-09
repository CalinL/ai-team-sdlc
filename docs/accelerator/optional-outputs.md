# Optional leave-behinds and next steps

[Accelerator home](README.md) | [Guide](guide.md)

**The interactive showcase is the core deliverable.** PDF and PowerPoint are optional
companions, not substitutes for browser verification, peer review, or the presenter test.
Do not generate them unless requested. Start from the final reviewed artifact and its sources.
Do not export a BLOCKED prototype as if it were executive-ready; any draft export must
explicitly retain its draft status and unresolved limitations.

## Add document skills only if you want an export

The relevant skills are `pdf` and `pptx`. They may need additional runtimes/packages
depending on the requested output; follow their setup instructions rather than installing
document tooling for every Accelerator participant.

**App:** open **Customize > Plugins**, add `anthropics/skills` through the marketplace
settings, then install **document-skills** from **anthropic-agent-skills**.
No separate CLI installation is needed for this route.

For Copilot CLI, the document-skills plugin can be installed separately:

```powershell
copilot plugin marketplace add anthropics/skills
copilot plugin install document-skills@anthropic-agent-skills
```

Confirm the relevant skill is available before requesting an output. Installing a plugin
does not prove that all of its rendering dependencies are ready.
The repository publishes the `anthropic-agent-skills` marketplace and `document-skills`
entry in its [marketplace manifest](https://github.com/anthropics/skills/blob/main/.claude-plugin/marketplace.json).
If your host rejects the format or restricts marketplace access, follow its supported
installation process; do not bypass policy.

## A short PDF pitch

```text
Use the pdf skill to create a concise executive leave-behind from the
reviewed showcase and its brief, one-pager and research: the problem,
the business reveal, supporting evidence, simulated capabilities and
next validation steps. Save it in docs without changing the prototype.
```

## A three-slide PowerPoint

```text
Use the pptx skill to create a three-slide executive leave-behind from
the reviewed showcase and its brief, one-pager and research:
1. The business problem and evidence.
2. The experience and decisive business reveal.
3. Assumptions, simulated capabilities and next validation steps.
Use the established brand guidance and save it in docs without changing
the prototype.
```

An exported document needs its own layout/content verification. Do not claim the HTML
critics also reviewed a PDF or deck they have not seen.

## Ready to move beyond the demo?

First validate the business case and scope with the relevant stakeholders.
Then use `ait-tech-specs` to translate the approved direction into requirements, acceptance
criteria and technical specifications, or explicitly request the broader `ait-sdlc-orchestrate`
lifecycle.

This is a **separate, larger delivery scope**, not the next automatic Accelerator step.
The prototype remains a throwaway representation of the intended experience. Production code
must be implemented and verified against the chosen stack; do not promote the HTML demo to
production.

The broader AI-SDLC includes implementation, QA, code review, security checks and mandatory
**Product Owner, Security Team and Tech Lead** sign-off before deployment. Adoption through
`ait-init`, if wanted, is an explicit configuration decision rather than a prototyping prerequisite.

## Source references

- [Document skills](https://github.com/anthropics/skills)
- [Technical specification skill](../../plugins/ai-team-sdlc/skills/ait-tech-specs/SKILL.md)
- [Full lifecycle orchestrator](../../plugins/ai-team-sdlc/skills/ait-sdlc-orchestrate/SKILL.md)
- [Shared sign-off contract](../../plugins/ai-team-sdlc/skills/ait-conventions/SKILL.md)
