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

# npm test: exit code and the number of passing tests node:test reports (a suite with no tests is not a pass).
function Invoke-NpmTest([string]$Repo) {
  Push-Location $Repo
  try {
    $out = npm test 2>&1 | Out-String; $code = $LASTEXITCODE
    $m = [regex]::Matches($out, '(?m)^\s*(?:#|\u2139)\s*pass\s+(\d+)') | Select-Object -Last 1
    [pscustomobject]@{ Exit = $code; Passed = $(if ($m) { [int]$m.Groups[1].Value } else { 0 }) }
  } finally { Pop-Location }
}

# Tracked and untracked (not ignored) paths that differ from a commit: what a release would ship beyond it.
function Get-ChangesSince([string]$Repo, [string]$Sha) {
  Push-Location $Repo
  try { @(@(git -c core.quotepath=off diff --name-only $Sha) + @(git -c core.quotepath=off ls-files --others --exclude-standard) | Where-Object { $_ } | Sort-Object -Unique) } finally { Pop-Location }
}

# The release candidate is the delivered tree: since that commit only the allowed record paths changed.
function Check-CandidateBound($R, [string]$Repo, [string]$Sha, [string]$Allowed, [string]$Tag) {
  $extra = @(Get-ChangesSince $Repo $Sha | Where-Object { $_ -notmatch $Allowed })
  Check $R "${Tag}: the working tree is the release candidate apart from new records$(if ($extra.Count) { ' (also changed: ' + ($extra -join ', ') + ')' })" (-not $extra.Count)
}

# Every plan/build/test task is done and no required gate is failed or unrun (before sign-off).
function Check-TasksComplete($R, $State, [string]$Tag) {
  $open = @($State.tasks | Where-Object { $_.phase -in 'plan', 'build', 'test' } | Where-Object {
      $t = $_; $t.status -ne 'done' -or @($t.requiredGates | Where-Object { "$($t.gateResults.$_)" -notin 'passed', 'skipped', 'waived' }).Count })
  Check $R "${Tag}: every plan, build and test task is done with its required gates$(if ($open.Count) { ' (open: ' + ($open.id -join ', ') + ')' })" (@($State.tasks).Count -and -not $open.Count)
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
  # Quoted human words may say "passed"; the rest of each line may not.
  $bad = @(($ap -split "`r?`n") | Where-Object { ($_ -replace '"[^"]*"|\u201c[^\u201d]*\u201d', '') -match '(?i)\b(passed|failed)\b|gate result|\d+/\d+ (tests|criteria)' })
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
