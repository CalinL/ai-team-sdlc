# Optional showcase extras

Read this only when the user has enabled one or more `showcase extras`. **Default: none.** Enable
an extra only on an explicit request (e.g. "write a business case", "make it multi-record", "add
an agentic layer"). Never infer one from the audience or the source.
Disabled extras are never unmet criteria. Features the source itself requires are not extras;
build them regardless.

| Extra | Path | Produces |
|---|---|---|
| `discovery` | both | `docs/<product>-discovery.md`: market scan + **proposed** demo scope |
| `portfolio` | generate only | Multi-record information architecture in the prototype + `docs/<product>-portfolio.md` (rationale and IA) |
| `agentic` | generate only | Visible, simulated AI-agent layer in the prototype + `docs/<product>-agentic.md` (where agents add value) |
| `business-case` | both | `docs/<product>-business-case.md` + a self-contained `docs/<product>-business-case.html` render |

Every extra writes markdown into the same output folder as the prototype (default `docs/`; see
SKILL.md **Output files**). Extras are documents, not versions: update them in place, and when the
user starts a new prototype version, keep them in sync with it.

Peer review (SKILL.md step 4) is not an extra: it always runs, and SKILL.md step 8 re-runs it on
the final version, including every extra.

On the **reproduce path**, `portfolio` and `agentic` never change the build. Match the source, and
list any suggestions separately in the handoff.

---

## `discovery`: market scan and proposed demo scope
When enabled, run this alongside SKILL.md step 1 (after reading the source, before building):
- **Must-demonstrate set.** List the features and flows the source asks for, quoted or closely
  paraphrased. Never silently drop one.
- **Personas.** Cover the operator, the reviewer/approver, and the sponsor.
- **Market scan.** Cover 3–6 comparable products or approaches: what they do, where they stop, and
  the gap. Cite and date it.
- **Proposed demo scope.** Split it into *in demo*, *showcase-only UX* and *roadmap*, plus
  non-goals. This is a **proposal**, not an approved MVP. Product commitments belong to the Product
  Owner's PRD. Never redefine approved requirements to fit the demo.
- **Open questions and assumptions.** Flag them; never invent facts.

## `portfolio`: designing for many records, not one
A first build usually models **one** unit of work: one request, case, file or project. If the user
enabled `portfolio`, design for many:
1. **Portfolio dashboard** (landing page). Show KPIs aggregated across units (volume, value,
   exceptions, cycle time, trend), grouped by the dimensions the business uses. Include at least one
   chart that tells a story.
2. **Unit list.** Make it searchable and filterable, with status, score, owner, value and last
   activity. Each row opens the unit.
3. **Start a new run.** Provide a clear primary action that ends with a new unit appearing in the
   list.
4. **Unit detail.** The original single-record screens become its **tabs**.

Seed 10–30 varied units (good, borderline, bad, in progress) — the user's real records where
supplied, otherwise mock data. Keep every number
consistent across the dashboard, list, detail and narration. If a structural change goes beyond
what the user enabled, propose it and wait for approval.

## `agentic`: a visible agent layer
For each in-scope feature, ask where a background agent would remove effort or add judgement.
Common roles are intake/extraction, matching, rule evaluation with explanations, anomaly detection,
drafting, triage and monitoring. Make the layer *visible* in the prototype:
- an agent roster (role, status, last action);
- a live activity log during a run;
- explainability on every AI output (why, evidence, confidence, which agent);
- human-in-the-loop controls (accept, override, escalate), with overrides recorded;
- a clear boundary: deterministic rules decide and agents advise, explain and draft. Say so in the
  UI.

Label the agents as simulated. Production agent architecture belongs to `ait-tech-specs`.

## `business-case`: companion document
This is presentation support. It is **not** an approved PRD, roadmap, acceptance specification or
production architecture; the PRD supersedes it. Write it to `docs/<product>-business-case.md`
unless the user asks otherwise. Adapt this outline rather than padding it:

```
# <Product> — Business Case
> Provenance note (below)
## Executive summary        — problem, answer, ask (≤ 8 lines)
## Problem & why now
## Personas
## Features                 — tiered: demonstrated · showcase UX · roadmap
## Use cases & scenarios
## Market context           — only if `discovery` ran; dated
## Success measures / KPIs  — from the source where possible
## Illustrative value       — formula + assumptions, labelled illustrative
## Agentic experience       — only if `agentic` is enabled; conceptual
## Risks & assumptions
## The ask
```

**Rules:**
- Tier every feature honestly.
- Every number carries its basis, and unvalidated figures are labelled as proposals.
- Use the same dataset as the prototype.

**Provenance note.** Open the document with a short block quote that states truthfully:
- the source and how it was obtained (ask the user if you don't know);
- that an AI assistant drafted it, naming the actual model;
- any AI review that actually happened, with models and rounds;
- that the human owners must validate it before external use.

Never claim a reviewer or round that did not happen.

**HTML render.** Convert it at authoring time into one self-contained file: no markdown library,
CDN or `fetch`. Reuse the prototype's theme and add a table of contents and print CSS. Regenerate
it whenever the markdown changes.

---

## Sync, traceability and readiness (when any extra is enabled)
- **Sync.** When the prototype changes, update the artifacts that were actually produced: the
  business case and its HTML, and the Simulate steps. Tell the user which ones changed.
- **Traceability.** Always map *source → prototype* (shown · partial · missing). Add business-case
  and narration columns only when those artifacts exist. Fix gaps or re-tier the item.
- **Readiness.** Check these before `done`. Include only the enabled items:
  - [ ] Every must-demonstrate feature from the source is visible and works.
  - [ ] Data is consistent everywhere; real data comes only from the user, and invented figures are
        labelled simulated.
  - [ ] (`portfolio`) Aggregates match the list and the details; filters are never empty.
  - [ ] (`agentic`) Agent outputs are explainable, overridable and labelled simulated.
  - [ ] (`business-case`) Provenance note, tiers and ask are present; the HTML matches the
        markdown.
  - [ ] (Simulate) The tour covers the main scenarios and lands on the strongest in-scope moment.
  - [ ] Final-version evidence: re-run 0 console errors, responsive and a11y checks after the
        last fix.
