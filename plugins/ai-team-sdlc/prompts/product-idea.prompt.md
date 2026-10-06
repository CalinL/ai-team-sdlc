---
description: 'Find high-impact business use cases for a company from its website using the ait-idea skill: deep research, ranked ideas, one-page HTML use cases, and build-ready prototype briefs for an executive demo.'
---

# Product idea (business use cases)

Apply the `ait-idea` skill.

Use this command before any design or prototype work, when you have a **company** (usually with its
website) and need **real, high-impact business use cases** worth demoing to leadership. Each one is
a UI/UX experience, with AI or agents behind the scenes where they earn their place.

Input may come from the text after the command, `${selection}`, or the current `${file}`: the
company name, website, number of use cases (default 3), audience, demo context, and any focus or
exclusions.

The skill produces the following, by default in `docs/`:
- a cited research dossier;
- a self-contained one-page HTML per use case;
- a markdown prototype brief per use case, covering screens, sample data, acceptance criteria and
  a demo runbook.

Before finishing, it runs critic review and a done-loop.

Hold the bar at executive readiness: real problems and a *wow* moment you would pitch to the CEO
yourself. If review does not reach READY, report the open findings rather than looping.

Keep this prompt as a thin router: load and follow the skill rather than re-implementing it here.
Return the skill's summary and the recommended next step. That is usually `/product-showcase`
with the chosen brief.
