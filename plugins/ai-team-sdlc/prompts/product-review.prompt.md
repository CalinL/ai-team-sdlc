---
description: 'Review implemented changes using the ait-review-critic skill.'
agent: ait-code-reviewer
---

# Product review

Apply the `ait-review-critic` skill and route the work to the `ait-code-reviewer` agent persona.

Use this command when the user wants a critic review of an implementation task, branch diff, pull
request, or changed files before marking work complete.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it as the review
scope, acceptance criteria, and any known risks.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
review logic here.

Follow the `ait-conventions` skill, including the result
contract and quality-gate order.

Return concise blocking findings, gate status, and next recommended phase.
