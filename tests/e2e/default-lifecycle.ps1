# Tier 4 — default-mode lifecycle, end to end through the Copilot CLI with the plugin from this tree.
# Part 1: idea → plan → build → test, stopping at the human sign-off gate.
# Part 2: scripted human approvals → sign-off → deploy (release records only; there is no target).
# Then asserts the 1.1.1 layout, the O2 rules, the tracking-store contents and a fresh clone.
# Cost: roughly 300–450 AI credits and 15 minutes (1.1.1 measurement). Usage:
#   pwsh tests/e2e/default-lifecycle.ps1 [-Model gpt-5.6-sol] [-MaxCredits 500] [-Keep]
param([string]$Model = 'gpt-5.6-sol', [double]$MaxCredits = 500, [switch]$Keep, [switch]$SkipPart2)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../agents/Harness.psm1') -Force
. (Join-Path $PSScriptRoot 'E2E.ps1')

$stamp = New-RunStamp
$out = Join-Path (Get-RepoRoot) "tests/out/e2e/default-$stamp"
$repo = Join-Path ([IO.Path]::GetTempPath()) "ait-tests/e2e-default-$stamp"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$fx = Join-Path (Get-RepoRoot) 'tests/fixtures/notes-api'
New-ScratchRepo $repo @{ 'idea.md' = [IO.File]::ReadAllText("$fx/idea.md"); 'package.json' = [IO.File]::ReadAllText("$fx/package.json"); '.gitignore' = [IO.File]::ReadAllText("$fx/gitignore.txt") }
$seedMain = Get-HeadSha $repo
$pluginVersion = [version](Get-Content (Join-Path (Get-PluginDir) 'plugin.json') -Raw | ConvertFrom-Json).version
Write-Host "Scratch repo: $repo`nTranscripts: $out" -ForegroundColor Cyan
$R = New-Report

Use-PluginUnderTest {
  # ---- Part 1: to sign-off
  Write-Host "[part 1] idea -> sign-off ($Model) ..." -ForegroundColor Cyan
  $p1 = Invoke-Copilot -Dir $repo -Model $Model -MaxCredits $MaxCredits -Log "$out/part1.log" -Prompt (
    'Use the ait-sdlc-orchestrate skill. Specs: idea.md. Run the full SDLC for this API-only service and stop at the human sign-off gate. ' +
    'Do not ask questions during the work: make reasonable assumptions and record them.')
  Write-Host "[part 1] done: $($p1.Credits) AI credits"
  $R.Credits += $p1.Credits

  $state = Get-RunState $repo
  $files = Get-AllFiles $repo
  $feature = @($files | Where-Object { $_ -match '^specs/features/(\d{3}-[a-z0-9-]+)/\1\.md$' })
  Check $R 'p1: a run state exists' ($null -ne $state)
  Check $R 'p1: state.json records the layout (1.1.1 run)' ($state.layout -and $state.layout.version -eq '1.1.1')
  Check $R 'p1: PRD at specs/prd.md' ($files -contains 'specs/prd.md')
  Check $R 'p1: a folder-named feature spec under specs/features/' ($feature.Count -ge 1)
  $fdir = if ($feature.Count) { (Split-Path $feature[0] -Parent).Replace('\', '/') } else { 'specs/features/<none>' }
  $plan = Read-Text $repo "$fdir/tasks.md"
  Check $R 'p1: the feature folder has stories.md and a static tasks.md (ref/story table, no status columns)' (($files -contains "$fdir/stories.md") -and $plan -match '\|\s*ref\s*\|\s*story\s*\|' -and $plan -notmatch '(?i)\|\s*(status|gateResults)\s*\|')
  Check $R 'p1: code and tests were written' (@($files | Where-Object { $_ -match '\.(c|m)?js$' -and $_ -notmatch '^(node_modules|specs|architecture|delivery|\.copilot-tracking)/' }).Count -ge 2)
  Check $R 'p1: a Proposed decision record in architecture/adr/' (@($files | Where-Object { $_ -match '^architecture/adr/\d{3,}-[a-z0-9-]+\.md$' -and (Read-Text $repo $_) -match 'Proposed' }).Count -ge 1)
  Check $R 'p1: results in delivery/results/' (@($files | Where-Object { $_ -match '^delivery/results/.+' }).Count -ge 1)
  Check $R 'p1: nothing written to docs/' (-not @($files | Where-Object { $_ -match '^docs/' }).Count)
  Check-TrackingStore $R $repo $state 'p1'
  Check-ApprovalsHumanOnly $R $repo 'p1'
  $left = @(Get-Uncommitted $repo)
  Check $R "p1: everything is committed$(if ($left.Count) { ' (uncommitted: ' + ($left -join ', ') + ')' })" (-not $left.Count)
  $nt = Invoke-NpmTest $repo
  Check $R "p1: npm test passes with real tests ($($nt.Passed) passing; need 3+)" ($nt.Exit -eq 0 -and $nt.Passed -ge 3)
  $sha = "$($state.signoff.artifact)"
  Check $R 'p1: the release candidate SHA is recorded and exists' ($sha -match '^[0-9a-f]{7,40}$' -and (Test-Commit $repo $sha))
  Check $R 'p1: sign-off is pending (no self-approval)' ($state.signoff.status -eq 'pending')
  Check-TasksComplete $R $state 'p1' $repo
  if ($sha -match '^[0-9a-f]{7,40}$') { Check-CandidateBound $R $repo $sha '^(delivery/approvals\.md|delivery/release/.+)$' 'p1' }
  if ($pluginVersion -ge [version]'1.1.2') {   # spec 1.1.2 §5.2 #1 and #9
    Push-Location $repo
    try { $main = (git rev-parse main).Trim(); $head = (git branch --show-current).Trim(); $work = @(git log --format=%H "$seedMain..ait/$($state.runId)" 2>$null) } finally { Pop-Location }
    Check $R 'p1: main did not move' ($main -eq $seedMain)
    Check $R 'p1: the run commits on ait/<run-id>, recorded in state.json.branch' ($state.branch -eq "ait/$($state.runId)" -and $head -eq $state.branch -and $work.Count -ge 1)
  }
  Save-Report $R "$out/report.md"

  if ($SkipPart2 -or -not $state) { return }
  # ---- Part 2: scripted human approvals, deploy
  $snapshot = Get-FileHashes $repo
  $approvalsAtSignoff = Read-Text $repo 'delivery/approvals.md'
  Write-Host "[part 2] sign-off -> deploy ..." -ForegroundColor Cyan
  $p2 = Invoke-Copilot -Dir $repo -Model $Model -MaxCredits $MaxCredits -Log "$out/part2.log" -Prompt (
    "Use the ait-sdlc-orchestrate skill to resume run $($state.runId). The three human approvers have answered in this turn, verbatim: " +
    'Product Owner Pat Lee: "Approved." Security Team Sam Roy: "No open findings, approved." Tech Lead Dana Kim: "Approved to ship." ' +
    "They approve release candidate $sha. Record the sign-off and continue to Deploy. There is no deployment target: prepare and commit the release records only, and touch nothing external. Don't ask questions.")
  Write-Host "[part 2] done: $($p2.Credits) AI credits"
  $R.Credits += $p2.Credits

  $state = Get-RunState $repo
  $ap = Read-Text $repo 'delivery/approvals.md'
  Check $R 'p2: sign-off approved with all three approvers' ($state.signoff.status -eq 'approved' -and $state.signoff.approvers.product_owner -and $state.signoff.approvers.security_team -and $state.signoff.approvers.tech_lead)
  Check $R 'p2: approvals.md names all three approvers with their verbatim quotes and is committed' ($ap -match 'Pat Lee' -and $ap -match 'Sam Roy' -and $ap -match 'Dana Kim' -and $ap -cmatch '"Approved\."' -and $ap -match 'No open findings, approved\.' -and $ap -match 'Approved to ship\.' -and (Test-Committed $repo 'delivery/approvals.md'))
  Check $R 'p2: approvals.md was appended to (earlier content is an unchanged prefix)' ($ap.Replace("`r`n", "`n").StartsWith($approvalsAtSignoff.Replace("`r`n", "`n")))
  Check $R 'p2: release records in delivery/release/' (@(Get-AllFiles $repo | Where-Object { $_ -match '^delivery/release/.+' }).Count -ge 1)
  $after = Get-FileHashes $repo
  $moved = @(@($after.Keys) + @($snapshot.Keys) | Sort-Object -Unique | Where-Object { $after[$_] -ne $snapshot[$_] } |
      Where-Object { $_ -notmatch '^\.copilot-tracking/' -and $_ -ne 'delivery/approvals.md' -and -not ($_ -match '^delivery/release/' -and -not $snapshot.ContainsKey($_)) })
  Check $R "p2: nothing changed after sign-off except approvals.md and new delivery/release/ files$(if ($moved.Count) { ': ' + ($moved -join ', ') })" (-not $moved.Count)
  Check-CandidateBound $R $repo $sha '^(delivery/approvals\.md|delivery/release/.+)$' 'p2'
  Check-TrackingStore $R $repo $state 'p2'
  Check-ApprovalsHumanOnly $R $repo 'p2'
  Check-FreshClone $R $repo @('specs/prd.md', 'delivery/approvals.md') @('^architecture/adr/', '^delivery/release/', '^delivery/results/')
}

Save-Report $R "$out/report.md"
Write-Host (Get-Content "$out/report.md" -Raw)
if (-not $Keep) { Remove-Scratch $repo } else { Write-Host "Kept: $repo" }
exit ([int]($R.Failed -gt 0))
