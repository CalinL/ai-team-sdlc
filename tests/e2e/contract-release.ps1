# Tier 4 — contract-mode release, end to end through the Copilot CLI with the plugin from this tree.
# API-only (no prototype gate). The human steps are scripted: this test writes the acceptance receipts
# (digests computed here, per ait-contract-mode §13) and passes the humans' confirmations verbatim.
#   Part 1: brief + PRD → stories, specs → blocked at spec-conformance (no code yet).
#   Part 2: receipts + confirmation → build and test → blocked at release-acceptance (candidate recorded).
#   Part 3: release receipt + confirmation + three approvals → sign-off → deploy (release records only).
# Cost: several hundred AI credits. Usage:
#   pwsh tests/e2e/contract-release.ps1 [-Model gpt-5.6-sol] [-MaxCredits 500] [-Keep] [-StopAfter 1|2|3]
param([string]$Model = 'gpt-5.6-sol', [double]$MaxCredits = 500, [switch]$Keep, [ValidateRange(1, 3)][int]$StopAfter = 3)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../agents/Harness.psm1') -Force
. (Join-Path $PSScriptRoot 'E2E.ps1')

$stamp = New-RunStamp
$out = Join-Path (Get-RepoRoot) "tests/out/e2e/contract-$stamp"
$repo = Join-Path ([IO.Path]::GetTempPath()) "ait-tests/e2e-contract-$stamp"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$fx = Join-Path (Get-RepoRoot) 'tests/fixtures'
$seed = @{
  '.github/ai-sdlc.yml'     = [IO.File]::ReadAllText("$fx/contract-notes/ai-sdlc.yml")
  'delivery/brief.md'       = [IO.File]::ReadAllText("$fx/contract-notes/brief.md")
  'specs/prd.md'            = [IO.File]::ReadAllText("$fx/contract-notes/prd.md")
  'architecture/overview.md' = [IO.File]::ReadAllText("$fx/contract-notes/overview.md")
  'package.json'            = [IO.File]::ReadAllText("$fx/notes-api/package.json")
  '.gitignore'              = [IO.File]::ReadAllText("$fx/notes-api/gitignore.txt")
}
New-ScratchRepo $repo $seed
$seedMain = Get-HeadSha $repo
$pluginVersion = [version](Get-Content (Join-Path (Get-PluginDir) 'plugin.json') -Raw | ConvertFrom-Json).version
function Test-BranchRule([string]$Tag, $State) {   # spec 1.1.2 §5.2 #1 and #6, in contract mode
  if ($pluginVersion -lt [version]'1.1.2') { return }
  Push-Location $repo; try { $main = (git rev-parse main).Trim(); $head = (git branch --show-current).Trim() } finally { Pop-Location }
  Check $R "${Tag}: main did not move; the run works on ait/<run-id>" ($main -eq $seedMain -and $State.branch -eq "ait/$($State.runId)" -and $head -eq $State.branch)
}
$inputs = Get-FileHashes $repo
Write-Host "Scratch repo: $repo`nTranscripts: $out" -ForegroundColor Cyan
$R = New-Report

function Sha256File([string]$Path) { (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant() }
function Write-Receipt([string]$Rel, [string]$Artifact, [string]$Digest) {
  Write-RepoFile $repo $Rel "---`nstatus: accepted`naccepted_by: Alex Chen`naccepted_at: 2026-01-05T10:00:00Z`nartifact: $Artifact`ndigest: $Digest`n---`nAccepted by the architecture owner.`n"
}
# Human receipts: only this test writes them, and the team must never edit, delete or add one.
$script:receipts = @{}
function Save-Receipts { foreach ($f in Get-AllFiles $repo | Where-Object { $_ -match '^delivery/(conformance/|results/acceptance-)' }) { $script:receipts[$f] = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo $f)).Hash } }
function Test-ReceiptsUntouched([string]$Tag) {
  $now = @(Get-AllFiles $repo | Where-Object { $_ -match '^delivery/(conformance/|results/acceptance-)' })
  $bad = @(@($now) + @($script:receipts.Keys) | Sort-Object -Unique | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repo $_)) -or -not $script:receipts.ContainsKey($_) -or (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repo $_)).Hash -ne $script:receipts[$_] })
  Check $R "${Tag}: human receipts untouched by the team$(if ($bad.Count) { ': ' + ($bad -join ', ') })" (-not $bad.Count)
}
function Test-InputsUnchanged([string]$Tag) {
  $now = Get-FileHashes $repo
  $changed = @('.github/ai-sdlc.yml', 'delivery/brief.md', 'specs/prd.md', 'architecture/overview.md' | Where-Object { $now[$_] -ne $inputs[$_] })
  Check $R "${Tag}: brief, PRD, config and protected overview unchanged$(if ($changed.Count) { ': ' + ($changed -join ', ') })" (-not $changed.Count)
  Check $R "${Tag}: architecture/ only gained new Proposed records" (-not @(Get-AllFiles $repo | Where-Object { $_ -match '^architecture/' -and $_ -ne 'architecture/overview.md' -and ($_ -notmatch '^architecture/adr/[^/]+\.md$' -or (Read-Text $repo $_) -notmatch 'Proposed') }).Count)
}

Use-PluginUnderTest {
  # ---- Part 1
  Write-Host "[part 1] brief -> specs, expect a stop at spec-conformance ..." -ForegroundColor Cyan
  $p = Invoke-Copilot -Dir $repo -Model $Model -MaxCredits $MaxCredits -Log "$out/part1.log" -Prompt (
    'Use the ait-sdlc-orchestrate skill and run this repository''s delivery. Do not ask questions during the work: make reasonable assumptions and record them; stop when the run needs a human.')
  $R.Credits += $p.Credits; Write-Host "[part 1] done: $($p.Credits) AI credits"
  $state = Get-RunState $repo
  $files = Get-AllFiles $repo
  $specs = @($files | Where-Object { $_ -match '^specs/features/(\d{3}-[a-z0-9-]+)/\1\.md$' })
  Check $R 'p1: run is in contract mode' ($state.mode -eq 'contract')
  Check $R 'p1: per-feature stories.md and a folder-named spec' ($specs.Count -ge 1 -and @($files | Where-Object { $_ -match '^specs/features/\d{3}-[a-z0-9-]+/stories\.md$' }).Count -ge 1)
  Check $R 'p1: no code before spec-conformance' (-not @($files | Where-Object { $_ -match '\.(c|m)?js$' -and $_ -notmatch '^(node_modules|\.copilot-tracking)/' }).Count)
  Check $R 'p1: build blocked by external:spec-conformance' (@($state.tasks | Where-Object { "$($_.blockedBy)" -match 'external:spec-conformance' }).Count -ge 1)
  Check $R 'p1: no PRD rewrite, no receipt written by the team' (-not @($files | Where-Object { $_ -match '^delivery/(conformance/|results/acceptance-)' }).Count)
  Test-InputsUnchanged 'p1'
  Test-BranchRule 'p1' $state
  Check-TrackingStore $R $repo $state 'p1'
  Save-Report $R "$out/report.md"
  if ($StopAfter -lt 2 -or -not $specs.Count) { return }

  # ---- Human step 1: conformance receipts, then confirmation in the prompt
  $quotes = foreach ($s in $specs) {
    $name = [IO.Path]::GetFileNameWithoutExtension($s); $d = Sha256File (Join-Path $repo $s)
    Write-Receipt "delivery/conformance/$name.md" $s $d
    "spec-conformance for $s, digest ${d}: `"Conforms to the architecture; go ahead.`""
  }
  Invoke-Git $repo @('add', '--', 'delivery/conformance'); Invoke-Git $repo @('commit', '-qm', 'Alex Chen: spec conformance receipts'); Save-Receipts
  Write-Host "[part 2] receipts written; build -> test, expect a stop at release-acceptance ..." -ForegroundColor Cyan
  $p = Invoke-Copilot -Dir $repo -Model $Model -MaxCredits $MaxCredits -Log "$out/part2.log" -Prompt (
    "Use the ait-sdlc-orchestrate skill to resume run $($state.runId). The architecture owner, Alex Chen, confirms in this turn, verbatim: " + ($quotes -join ' ') +
    ' Continue the run. Do not ask questions during the work; stop when the run needs a human.')
  $R.Credits += $p.Credits; Write-Host "[part 2] done: $($p.Credits) AI credits"
  $state = Get-RunState $repo
  $ap = Read-Text $repo 'delivery/approvals.md'
  $sha = "$($state.signoff.artifact)"
  Check $R 'p2: approvals.md holds the spec-conformance confirmation with its digest' ($ap -match 'spec-conformance' -and $ap -match 'Conforms to the architecture; go ahead\.' -and $ap -match [regex]::Escape((Sha256File (Join-Path $repo $specs[0]))))
  $nt = Invoke-NpmTest $repo
  Check $R "p2: code written; npm test passes with real tests ($($nt.Passed) passing; need 3+)" (@(Get-AllFiles $repo | Where-Object { $_ -match '\.(c|m)?js$' -and $_ -notmatch '^(node_modules|specs|architecture|delivery|\.copilot-tracking)/' }).Count -ge 2 -and $nt.Exit -eq 0 -and $nt.Passed -ge 3)
  $pc = @($state.tasks | Where-Object { $_.phase -in 'build', 'test' -and $_.requiredGates -contains 'path-check' })
  Check $R 'p2: every build and test task is done and passed path-check' ($pc.Count -and -not @($pc | Where-Object { $_.status -ne 'done' -or $_.gateResults.'path-check' -ne 'passed' }).Count)
  Check-TasksComplete $R $state 'p2' $repo
  Test-ReceiptsUntouched 'p2'
  Check $R 'p2: release candidate SHA recorded before release-acceptance' ($sha -match '^[0-9a-f]{7,40}$' -and (Test-Commit $repo $sha))
  Check $R 'p2: sign-off still pending' ($state.signoff.status -ne 'approved')
  if ($sha -match '^[0-9a-f]{7,40}$') { Check-CandidateBound $R $repo $sha '^delivery/approvals\.md$' 'p2' }
  Test-InputsUnchanged 'p2'
  Test-BranchRule 'p2' $state
  Check-ApprovalsHumanOnly $R $repo 'p2'
  Save-Report $R "$out/report.md"
  if ($StopAfter -lt 3 -or $sha -notmatch '^[0-9a-f]{7,40}$') { return }

  # ---- Human step 2: release acceptance + sign-off
  $snapshot = Get-FileHashes $repo
  Write-Receipt "delivery/results/acceptance-$sha.md" 'release candidate' $sha
  Invoke-Git $repo @('add', '--', "delivery/results/acceptance-$sha.md"); Invoke-Git $repo @('commit', '-qm', 'Alex Chen: release acceptance'); Save-Receipts
  Write-Host "[part 3] release receipt + approvals; sign-off -> deploy ..." -ForegroundColor Cyan
  $p = Invoke-Copilot -Dir $repo -Model $Model -MaxCredits $MaxCredits -Log "$out/part3.log" -Prompt (
    "Use the ait-sdlc-orchestrate skill to resume run $($state.runId). In this turn, verbatim: Alex Chen confirms release-acceptance for release candidate $sha, digest ${sha}: `"Release accepted.`" " +
    'Product Owner Pat Lee: "Approved." Security Team Sam Roy: "No open findings, approved." Tech Lead Dana Kim: "Approved to ship." ' +
    "They approve release candidate $sha. Record the sign-off and continue to Deploy. There is no deployment target: prepare and commit the release records only, and touch nothing external. Don't ask questions.")
  $R.Credits += $p.Credits; Write-Host "[part 3] done: $($p.Credits) AI credits"
  $state = Get-RunState $repo
  $ap = Read-Text $repo 'delivery/approvals.md'
  Check $R 'p3: release-acceptance confirmation recorded' ($ap -match 'release-acceptance' -and $ap -match 'Release accepted\.')
  Check $R 'p3: sign-off approved by all three, names and quotes in approvals.md' ($state.signoff.status -eq 'approved' -and $state.signoff.approvers.product_owner -and $state.signoff.approvers.security_team -and $state.signoff.approvers.tech_lead -and $ap -match 'Pat Lee' -and $ap -match 'Sam Roy' -and $ap -match 'Dana Kim' -and $ap -match 'Approved to ship\.' -and $ap -match 'No open findings, approved\.')
  Check $R 'p3: deploy ships the candidate without re-pinning' ("$($state.signoff.artifact)" -eq $sha)
  Check $R 'p3: release records in delivery/release/' (@(Get-AllFiles $repo | Where-Object { $_ -match '^delivery/release/.+' }).Count -ge 1)
  $after = Get-FileHashes $repo
  $moved = @(@($after.Keys) + @($snapshot.Keys) | Sort-Object -Unique | Where-Object { $after[$_] -ne $snapshot[$_] } |
      Where-Object { $_ -notmatch '^\.copilot-tracking/' -and $_ -ne 'delivery/approvals.md' -and $_ -ne "delivery/results/acceptance-$sha.md" -and -not ($_ -match '^delivery/release/' -and -not $snapshot.ContainsKey($_)) })
  Check $R "p3: after the candidate only records changed$(if ($moved.Count) { ': ' + ($moved -join ', ') })" (-not $moved.Count)
  Test-InputsUnchanged 'p3'
  Test-BranchRule 'p3' $state
  Check-ApprovalsHumanOnly $R $repo 'p3'
  Check-CandidateBound $R $repo $sha '^(delivery/approvals\.md|delivery/release/.+|delivery/results/acceptance-[^/]+\.md)$' 'p3'
  Test-ReceiptsUntouched 'p3'
  Check-FreshClone $R $repo @('delivery/approvals.md', "delivery/results/acceptance-$sha.md") @('^specs/features/\d{3}-[a-z0-9-]+/stories\.md$', '^delivery/conformance/', '^delivery/release/')
}

Save-Report $R "$out/report.md"
Write-Host (Get-Content "$out/report.md" -Raw)
if (-not $Keep) { Remove-Scratch $repo } else { Write-Host "Kept: $repo" }
exit ([int]($R.Failed -gt 0))
