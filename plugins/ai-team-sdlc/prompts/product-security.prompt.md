---
description: 'Run security and responsible-AI validation using the ait-security skill.'
agent: ait-security-rai
---

# Product security

Apply the `ait-security` skill and route the work to the `ait-security-rai` agent persona.

Use this command when the user wants security, secret, dependency/SCA, SAST, or responsible-AI
validation for an implementation task or release candidate.

Input may come from the text after the command, `${selection}`, or the current `${file}`. Treat it as the security
scope, changed files, threat context, acceptance criteria, and tracking paths.

Keep this prompt as a thin router: load and follow the skill procedure rather than re-implementing
security logic here.

Follow the `ait-conventions` skill. Run only configured tools
and report skipped gates when tooling is not present.

Return concise security findings, gate status, decisions, and next recommended phase.
