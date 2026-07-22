---
description: 'Prepare or execute deployment using the ait-deploy skill after human sign-off.'
agent: ait-devops
---

# Product deploy

Apply the `ait-deploy` skill and route the work to the `ait-devops` agent persona.

Use this command when the user wants release preparation, deployment steps, infrastructure changes,
or rollback planning for completed AI-SDLC work.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it as the release
scope, environment, tracking path, and gate evidence.

Require the mandatory human sign-off gate before deployment: Product Owner, Security Team, and
Tech Lead must approve. If sign-off is missing, pause and request it.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
deployment logic here.

Follow the `ait-conventions` skill, surfacing risky or
destructive actions for explicit approval.

Return deployment status, rollback notes, gates, and whether `DONE` can be reported.
