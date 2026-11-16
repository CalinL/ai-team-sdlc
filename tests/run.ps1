# Run the ai-team-sdlc test suite. Tiers 1–2 are free and deterministic (and run in CI); tiers 3–4
# call models through the Copilot CLI and cost AI credits. See tests/README.md.
#   pwsh tests/run.ps1                      # static + recipes (+ agent-harness dry run)
#   pwsh tests/run.ps1 -Tier agents -Case layout-*
#   pwsh tests/run.ps1 -Tier e2e -E2E default
param(
  [ValidateSet('static', 'recipes', 'agents', 'e2e', 'free', 'all')][string]$Tier = 'free',
  [string[]]$Case = @('*'),              # agents: case-name wildcards
  [int]$Runs = 0,                        # agents: override runs per case
  [string]$Model = '',                   # agents/e2e: override the model
  [ValidateSet('default', 'contract', 'both')][string]$E2E = 'default'
)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$env:PYTHONIOENCODING = 'utf-8'
$python = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } else { 'python' }
$results = [ordered]@{}

function Step([string]$Name, [scriptblock]$Body) {
  Write-Host "`n### $Name" -ForegroundColor Cyan
  & $Body
  $results[$Name] = if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'FAIL' }
}

if ($Tier -in 'static', 'free', 'all') {
  Step 'static checks' { & $python "$here/static/check_static.py" }
  Step 'static self-test' { & $python "$here/static/self_test.py" }
}
if ($Tier -in 'recipes', 'free', 'all') {
  Step 'recipes' { & $python "$here/recipes/run_recipes.py" }
}
if ($Tier -in 'free', 'all') {
  Step 'agent harness dry run' { pwsh -NoProfile -File "$here/agents/run_agents.ps1" -DryRun -Runs 1 }
}
if ($Tier -in 'agents', 'all') {
  Step 'agent probes' {
    $p = @{ Case = $Case }; if ($Runs) { $p.Runs = $Runs }; if ($Model) { $p.Model = $Model }
    & "$here/agents/run_agents.ps1" @p
  }
}
if ($Tier -in 'e2e', 'all') {
  $p = @{}; if ($Model) { $p.Model = $Model }
  if ($E2E -in 'default', 'both') { Step 'e2e default lifecycle' { & "$here/e2e/default-lifecycle.ps1" @p } }
  if ($E2E -in 'contract', 'both') { Step 'e2e contract release' { & "$here/e2e/contract-release.ps1" @p } }
}

Write-Host "`n### Summary" -ForegroundColor Cyan
$results.GetEnumerator() | ForEach-Object { '{0,-5} {1}' -f $_.Value, $_.Key }
exit ([int](@($results.Values | Where-Object { $_ -eq 'FAIL' }).Count -gt 0))
