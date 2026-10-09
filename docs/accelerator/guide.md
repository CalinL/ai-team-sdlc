# From opportunity to executive showcase

[Accelerator home](README.md) | [Prerequisites](prerequisites.md) | [Troubleshooting](troubleshooting.md)

**Choose one route:** run the fast track, or work through the guided steps.
Do not send the separate discovery/build prompts while the chained prompt is already running.
Replace whole placeholders. Prompts go into Copilot, not the terminal.
Replace the company, website and chosen case number yourself. Copilot chooses the product
filename; you do not need to supply a slug.

**Let the skills do their job.** Prompts supply the goal, inputs, and feedback. The skills
already define design, verification, review, Simulate, versioning, and readiness; do not
paste a second workflow over them. The handoff notes below explain how to interpret the
inputs, not replace either skill's procedure.

## Fast track: one prompt

Complete [setup and checks](prerequisites.md). In **CLI**, enable `/autopilot`;
in the **GitHub Copilot App**, select **Autopilot** below the prompt box.
Saying "autopilot" in a prompt is not a substitute for configuring the mode.
Check permissions in your interface before an unattended run. In CLI, manual approval
in autopilot denies requests needing approval rather than stopping to ask. Use the
interactive guided route if an unattended run cannot be safely authorized.

**Using the App?** Keep the session in your chosen local repository, not a new working
tree or cloud sandbox. Paste the same prompt below into the project's agent session.

```text
Run on autopilot: use the ait-idea skill to find 2 business use cases for
<Company> from <https://www.company.com>. Once ideation is READY, use the
ait-product-showcase skill to build an executive showcase from use case 01
in docs. Use its brief as the product requirements, with its one-pager
and research as narrative, brand and evidence context—not a UI to reproduce.
```

Both skills use `docs` by default. The brief drives the product experience; the one-pager
is the pitch, not a screen design. The skills own file naming, review and stop conditions;
a NOT READY discovery must not be treated as an approved build input.

**Your job while it runs:** open the one-pagers and brief as they appear, understand the
problem, and note what would make the pitch compelling. Do not edit files being generated.
A file appearing on disk does not mean it has passed review.

## Guided route

### 1. Discover two opportunities

```text
Use the ait-idea skill to find 2 business use cases for <Company>
from <https://www.company.com>.
```

Expect a research dossier, two HTML one-pagers, and two Markdown prototype briefs.
The dossier contains citations, evidence classes, brand guidance, and ranked ideas.

Check that the result is READY. Independent critics are preferred when available;
the skill's self-review fallback must be disclosed if used. If ideation is NOT READY,
resolve its findings before building.

### 2. Choose what deserves the room

The fast track builds **01**. In the guided route, you may choose a different numbered case.
Read its one-pager and brief and answer:

1. Who is the user, and what business friction are they facing?
2. Is that friction confirmed, an industry hypothesis, or an inference?
3. What happens on screen that makes the idea worth exploring?
4. What evidence supports the company's strategic fit?
5. What would the CEO challenge first?

Prefer one convincing reveal to many disconnected features. AI or agents are useful only
when they earn their place; a good business idea does not need an agentic label.

**Already have a brief?** Skip discovery. Describe the user, problem, scope, screen flow,
sample data, and intended reveal. Provide public-safe evidence and brand guidance.
The showcase skill still owns verification, review, and readiness.

### 3. Build the showcase

```text
Use the ait-product-showcase skill to build an executive showcase from
use case <NN> in docs. Use its brief as the product requirements, with
its one-pager and research as narrative, brand and evidence context—not
a UI to reproduce.
```

The workflow includes design preparation, the build, browser checks, peer review,
source-fidelity validation, Simulate, and final-version verification/review.
The design preparation is part of showcase, not an optional business-case extra.

The one-pager is a **pitch**, not a UI wireframe.

### 4. Read while it builds

Understand the story before judging the visuals. Read the brief and note two useful changes:
one that improves the business reveal, and one that makes the experience clearer.
Do not start a second build in the same workspace or send duplicate build requests.

If you need a checkpoint, use:

```text
Give me a readiness checkpoint: what exists, which checks and reviews have
passed, what remains, and any blockers.
```

### 5. Inspect, refine, replay

Open the generated `docs/<product>-v1.html` in a browser. Start **Simulate** with a click.
Read the bottom transcript, test the controls actually supplied, and inspect the critical
flows yourself. Speech availability depends on the browser; missing narration must leave
the transcript and manual walkthrough usable.

Use focused feedback instead of asking for "more wow" without direction:

```text
The reveal should help <persona> understand or decide <specific thing>.
Use the ait-product-showcase skill to improve <screen/interaction>
within the existing brief and update Simulate.
```

```text
Act as a sceptical executive. Identify the 3 hardest questions this
prototype leaves unanswered. Suggest improvements before making changes.
```

After changes, ask which file was updated and refresh it. Re-test the reveal and reset/replay.
A previously READY verdict does not automatically cover a changed prototype.

### 6. Earn the final verdict

This checklist is a participant-facing view of the skills' criteria, not a replacement:

| Check | Evidence to look for |
|---|---|
| Credible problem | Cited claims; hypotheses/inferences remain identified; no invented outcome promises. |
| Business reveal | A specific improvement the intended persona can see and explain. |
| Visual confidence | Company style or disclosed neutral fallback; readable text and contrast. |
| Coverage | The source inventory is accounted for; critical clicks and states work. |
| Honest simulation | Persistent disclosure; no implication of live integrations or production readiness. |
| Repeatable tour | Simulate, transcript, controls, reset/replay, and usable speech fallback. |
| Browser verification | Critical flows, console health, responsive checks, and accessibility smoke evidence. |
| Final peer review | Both independent showcase critics READY on the version including Simulate. |
| Presenter test | You would present it yourself and can defend the pitch without apologies. |

**Two separate review budgets:** ideation has up to three rounds under its own contract.
Showcase has three rounds **total across its intermediate and final reviews**, not three
per pass. Each round can involve two critics; time and usage depend on the findings.

**Missing reviewers:** ideation can use its disclosed self-review fallback.
The unattended showcase stops BLOCKED if independent reviewers are unavailable.
Only explicit user action may request the showcase skill's recorded-waiver/human-review
route outside this unattended track; the agent must never select or approve it itself.

**Budget exhausted:** report the remaining concerns and BLOCKED status. Do not restart
the review counter, delete the standout feature to obtain an easy pass, or claim completion.

Authoritative criteria:
[Ideation review and done-loop](../../plugins/ai-team-sdlc/skills/ait-idea/SKILL.md) |
[Showcase final-version check and acceptance](../../plugins/ai-team-sdlc/skills/ait-product-showcase/SKILL.md).

### 7. Present the idea, not the machinery

A useful short presentation:

- **Problem:** the user, the friction, and what is evidenced versus hypothetical.
- **Reveal:** show the decisive interaction or Simulate highlights, not every screen.
- **Next validation:** explain what is simulated and which assumption needs stakeholder validation.

Do not present a BLOCKED artifact as executive-ready. It can be shown as a clearly labelled
work-in-progress if the audience understands its limitations.

## Facilitate a session

Prepare setup before the session. Begin with a short exemplar, then move through discovery,
selection, building, and participant review. Let participants read while the AI works.
Reserve time for the business pitch and questions; use progress checkpoints, not deadlines
that waive gates. One complete showcase is more valuable than several unfinished builds.

For follow-up materials or production planning, see [optional outputs](optional-outputs.md).
