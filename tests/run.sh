#!/usr/bin/env bash
# Free tiers of the ai-team-sdlc test suite (static checks + recipes). Agent probes and E2E runs need
# PowerShell 7 and the Copilot CLI: see tests/README.md.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
py="$(command -v python3 || command -v python)"
export PYTHONIOENCODING=utf-8
fail=0
for step in "static/check_static.py" "static/self_test.py" "recipes/run_recipes.py"; do
  printf '\n### %s\n' "$step"
  "$py" "$here/$step" || fail=1
done
if command -v pwsh >/dev/null 2>&1; then
  printf '\n### agents/run_agents.ps1 -DryRun\n'
  pwsh -NoProfile -File "$here/agents/run_agents.ps1" -DryRun -Runs 1 || fail=1
fi
printf '\n%s\n' "$([ "$fail" -eq 0 ] && echo 'ALL PASS' || echo 'FAILURES')"
exit "$fail"
