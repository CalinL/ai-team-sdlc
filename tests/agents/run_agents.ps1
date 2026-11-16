# Tier 3 — run agent probes: each case seeds a scratch repo, runs one prompt through the plugin under
# test, and grades what the run left behind. A case passes when at least Pass of Runs runs pass.
# Costs AI credits (see tests/README.md). Usage:
#   pwsh tests/agents/run_agents.ps1 -List
#   pwsh tests/agents/run_agents.ps1 -Case layout-placement -Runs 1
#   pwsh tests/agents/run_agents.ps1                       # every case, its default runs and model
param(
  [string[]]$Case = @('*'),
  [int]$Runs = 0,                 # override every case's run count (and scale its pass threshold)
  [string]$Model = '',            # override every case's model
  [double]$MaxCredits = 60,       # soft cap per run (copilot --max-ai-credits)
  [switch]$List,
  [switch]$DryRun,               # seed and grade every case without calling a model (harness self-check; no credits)
  [switch]$KeepScratch
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force

$cases = foreach ($f in Get-ChildItem (Join-Path $PSScriptRoot 'cases') -Filter '*.ps1' | Sort-Object Name) {
  foreach ($c in @(& $f.FullName)) { $c.File = $f.Name; $c }
}
$cases = @($cases | Where-Object { $n = $_.Name; @($Case | Where-Object { $n -like $_ }).Count })
if ($List -or -not $cases.Count) {
  $cases | ForEach-Object { '{0,-34} {1,-18} runs={2} pass>={3}  {4}' -f $_.Name, $_.Model, $_.Runs, $_.Pass, $_.Covers }
  if (-not $cases.Count) { Write-Warning "No case matches '$($Case -join ', ')'."; exit 1 }
  exit 0
}
if (-not $DryRun -and -not (Get-Command copilot -ErrorAction SilentlyContinue)) { throw 'The Copilot CLI (copilot) is not on PATH.' }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path (Get-RepoRoot) "tests/out/agents/$stamp"
$scratchRoot = Join-Path ([IO.Path]::GetTempPath()) "ait-tests/$stamp"
New-Item -ItemType Directory -Force -Path $out, $scratchRoot | Out-Null
$plan = foreach ($c in $cases) {
  $n = if ($Runs) { $Runs } else { $c.Runs }
  $p = if ($Runs) { [Math]::Max(1, [Math]::Ceiling($c.Pass * $n / $c.Runs)) } else { $c.Pass }
  [pscustomobject]@{ Case = $c; Runs = $n; Pass = $p; Model = $(if ($Model) { $Model } else { $c.Model }) }
}
$total = ($plan | Measure-Object Runs -Sum).Sum
Write-Host "Agent probes: $($plan.Count) case(s), $total run(s). Transcripts: $out" -ForegroundColor Cyan

$results = [Collections.Generic.List[object]]::new()
$started = Get-Date; $st = @{ Done = 0; Credits = 0.0 }   # mutable: the body runs in a child scope
$body = {
  foreach ($p in $plan) {
    $c = $p.Case; $ok = 0
    $dir = Join-Path $out $c.Name; New-Item -ItemType Directory -Force -Path $dir | Out-Null
    for ($i = 1; $i -le $p.Runs; $i++) {
      $repo = Join-Path $scratchRoot "$($c.Name)-$i"
      New-ScratchRepo $repo $(if ($c.Files) { $c.Files.Clone() } else { @{} })
      if ($c.Setup) { Push-Location $repo; try { & $c.Setup $repo $c } finally { Pop-Location } }
      $before = Get-FileHashes $repo
      $eta = if ($st.Done) { ' ETA ' + [TimeSpan]::FromSeconds(((Get-Date) - $started).TotalSeconds / $st.Done * ($total - $st.Done)).ToString('hh\:mm\:ss') } else { '' }
      Write-Host ("[{0}/{1}] {2} run {3}/{4} ({5}){6}" -f ($st.Done + 1), $total, $c.Name, $i, $p.Runs, $p.Model, $eta)
      $t0 = Get-Date
      $r = if ($DryRun) { $l = Join-Path $dir "run-$i.log"; '' | Out-File $l; [pscustomobject]@{ Log = $l; Credits = 0.0 } } else { Invoke-Copilot -Dir $repo -Prompt $c.Prompt -Model $p.Model -Agent $c.Agent -Log (Join-Path $dir "run-$i.log") -MaxCredits $MaxCredits }
      $changed = @(Get-ChangedFiles $repo $before)
      $fails = @(Push-Location $repo; try { & $c.Check $repo (Get-Transcript $r.Log) $changed $c } finally { Pop-Location }) | Where-Object { $_ }
      $st.Done++; $st.Credits += $r.Credits
      if ($fails.Count) { Write-Host "    FAIL ($([int]((Get-Date) - $t0).TotalSeconds)s, $($r.Credits) cr): $($fails -join ' | ')" -ForegroundColor Yellow }
      else { $ok++; Write-Host "    pass ($([int]((Get-Date) - $t0).TotalSeconds)s, $($r.Credits) cr)" -ForegroundColor Green }
      "changed: $($changed -join ', ')`nfailures:`n$(($fails | ForEach-Object { "- $_" }) -join "`n")" | Out-File (Join-Path $dir "run-$i.grade.txt") -Encoding utf8
      if (-not $KeepScratch) { Remove-Scratch $repo }
    }
    $results.Add([pscustomobject]@{ Case = $c.Name; Covers = $c.Covers; Model = $p.Model; Passed = $ok; Runs = $p.Runs; Needed = $p.Pass; Result = $(if ($ok -ge $p.Pass) { 'PASS' } else { 'FAIL' }) })
  }
}
if ($DryRun) { & $body } else { Use-PluginUnderTest $body }
$credits = $st.Credits

$table = $results | Format-Table Case, Model, @{ n = 'Score'; e = { "$($_.Passed)/$($_.Runs)" } }, @{ n = 'Needed'; e = { ">=$($_.Needed)" } }, Result, Covers -AutoSize | Out-String -Width 220
$summary = "# Agent probes $stamp`n`nElapsed $(((Get-Date) - $started).ToString('hh\:mm\:ss')), $([Math]::Round($credits, 1)) AI credits.`n`n``````$table``````"
$summary | Out-File (Join-Path $out 'summary.md') -Encoding utf8
Write-Host $table
Write-Host "agents: $(@($results | Where-Object Result -eq 'PASS').Count)/$($results.Count) cases passed, $([Math]::Round($credits, 1)) AI credits" -ForegroundColor Cyan
if (-not $KeepScratch) { Remove-Scratch $scratchRoot }
if ($DryRun) {
  # Self-check: with no model call every case must fail; one that passes on an untouched seed proves nothing.
  $weak = @($results | Where-Object Passed -gt 0)
  Write-Host "dry run: $($results.Count - $weak.Count)/$($results.Count) cases fail on an untouched seed, as they must" -ForegroundColor Cyan
  if ($weak.Count) { Write-Host "weak cases (pass with no work done): $($weak.Case -join ', ')" -ForegroundColor Yellow }
  exit ([int]($weak.Count -gt 0))
}
exit ([int](@($results | Where-Object Result -eq 'FAIL').Count -gt 0))
