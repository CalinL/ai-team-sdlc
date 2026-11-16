# Shared assertions for the tier-4 end-to-end scripts (dot-source after importing ../agents/Harness.psm1).

function New-Report { [pscustomobject]@{ Rows = [Collections.Generic.List[object]]::new(); Failed = 0; Credits = 0.0 } }

function Check($R, [string]$Name, $Ok) {
  $pass = [bool]$Ok
  $R.Rows.Add([pscustomobject]@{ Result = $(if ($pass) { 'PASS' } else { 'FAIL' }); Check = $Name })
  if (-not $pass) { $R.Failed++ }
  Write-Host ("  {0}  {1}" -f $(if ($pass) { 'PASS' } else { 'FAIL' }), $Name) -ForegroundColor $(if ($pass) { 'Green' } else { 'Yellow' })
}

function Save-Report($R, [string]$Path) {
  $lines = @("# E2E report", '', "$($R.Rows.Count - $R.Failed)/$($R.Rows.Count) checks passed, $([Math]::Round($R.Credits, 1)) AI credits.", '', '| Result | Check |', '|---|---|') +
    @($R.Rows | ForEach-Object { "| $($_.Result) | $($_.Check.Replace('|', '\|')) |" })
  [IO.File]::WriteAllText($Path, ($lines -join "`n") + "`n")
}

# The newest run's state.json under .copilot-tracking/ (a run writes exactly one).
function Get-RunState([string]$Repo) {
  $f = Get-ChildItem (Join-Path $Repo '.copilot-tracking') -Filter state.json -Recurse -Depth 1 -Force -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
  if ($f) { [IO.File]::ReadAllText($f.FullName) | ConvertFrom-Json }
}

function Get-Uncommitted([string]$Repo) {
  Push-Location $Repo
  try { @(git -c core.quotepath=off status --porcelain --untracked-files=all | ForEach-Object { $_.Substring(3).Trim('"').Replace('\', '/') }) } finally { Pop-Location }
}

function Test-Commit([string]$Repo, [string]$Sha) { Push-Location $Repo; try { git cat-file -e "$Sha^{commit}" 2>$null; $LASTEXITCODE -eq 0 } finally { Pop-Location } }

function Invoke-NpmTest([string]$Repo) {
  Push-Location $Repo
  try { npm test --silent 2>&1 | Out-Null; $LASTEXITCODE } finally { Pop-Location }
}

# 1.1.1 §2.5: a new run's tracking store holds only state.json, plan.md, inbox/ and path-check baselines.
function Check-TrackingStore($R, [string]$Repo, $State, [string]$Tag) {
  if (-not $State) { Check $R "${Tag}: tracking store (no run found)" $false; return }
  $base = ".copilot-tracking/$($State.runId)/"
  $extra = @(Get-AllFiles $Repo | Where-Object { $_.StartsWith($base) } | ForEach-Object { $_.Substring($base.Length) } |
      Where-Object { $_ -notmatch '^(state\.json|plan\.md|inbox/.*|baselines/.*|[^/]*(path-check|baseline)[^/]*)$' })
  Check $R "${Tag}: tracking store holds only state.json, plan.md, inbox/, baselines/$(if ($extra.Count) { ' (extra: ' + ($extra -join ', ') + ')' })" (-not $extra.Count)
}

# 1.1.1 rule 2 (and the af4417d regression): approvals.md holds human-sourced records only.
function Check-ApprovalsHumanOnly($R, [string]$Repo, [string]$Tag) {
  $ap = Read-Text $Repo 'delivery/approvals.md'
  $bad = @(($ap -split "`r?`n") | Where-Object { $_ -match '(?i)\b(passed|failed)\b|gate result|\d+/\d+ (tests|criteria)' })
  Check $R "${Tag}: approvals.md holds no agent gate results$(if ($bad.Count) { ' (' + ($bad[0].Trim()) + ')' })" (-not $bad.Count)
}

# 1.1.1 §8.2 #10: everything durable survives a fresh clone (nothing lives only in .copilot-tracking/).
function Check-FreshClone($R, [string]$Repo, [string[]]$Files, [string[]]$Patterns) {
  $clone = "$Repo-clone"
  Remove-Scratch $clone
  git clone -q $Repo $clone 2>&1 | Out-Null
  try {
    $got = Get-AllFiles $clone
    $missing = @($Files | Where-Object { $got -notcontains $_ }) + @($Patterns | Where-Object { $p = $_; -not @($got | Where-Object { $_ -match $p }).Count })
    Check $R "fresh clone holds every record$(if ($missing.Count) { ' (missing: ' + ($missing -join ', ') + ')' })" (-not $missing.Count)
  } finally { Remove-Scratch $clone }
}
