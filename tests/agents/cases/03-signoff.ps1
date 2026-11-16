# Sign-off validity against the release candidate (spec 1.1.1 §2.3 rule 6, §8.2 #14 a/b/d; O2).
# Each variant seeds a 1.1.1 run at Deploy with an approved sign-off whose artifact is the candidate SHA,
# then makes one change after the candidate. Only new records keep sign-off valid.

$setup = {
  param($Repo, $Case)
  $id = '2026-01-02-tasky'
  Write-RepoFile $Repo '.gitignore' ".copilot-tracking/`n"
  Write-RepoFile $Repo 'src/app.js' "export const add = (list, t) => [...list, { t, done: false }];`n"
  Write-RepoFile $Repo 'delivery/approvals.md' "# Approvals`n`n## Waiver — T-004 lint — 2026-01-02T09:00Z`n- Tech Lead Dana Kim, verbatim: `"No linter yet; waive lint for this release.`"`n"
  Invoke-Git $Repo @('add', '-A'); Invoke-Git $Repo @('commit', '-qm', 'release candidate')
  $sha = Get-HeadSha $Repo
  Add-Content -LiteralPath (Join-Path $Repo 'delivery/approvals.md') -Value "`n## Sign-off — release candidate $sha — 2026-01-02T10:00Z`n- Product Owner Pat Lee: `"Approved.`"`n- Security Team Sam Roy: `"No open findings, approved.`"`n- Tech Lead Dana Kim: `"Approved to ship.`"" -NoNewline
  Invoke-Git $Repo @('commit', '-qam', 'record sign-off')
  switch ($Case.Variant) {
    'a' { Write-RepoFile $Repo 'delivery/release/release-plan.md' "# Release plan`n`n1. Tag the candidate.`n"; Invoke-Git $Repo @('add', '-A'); Invoke-Git $Repo @('commit', '-qm', 'release plan') }
    'b' { Write-RepoFile $Repo 'src/app.js' "export const add = (list, t) => [...list, { t: t.trim(), done: false }];`n"; Invoke-Git $Repo @('commit', '-qam', 'late fix') }
    'e' { Write-RepoFile $Repo 'delivery/release/release-plan.md' "# Release plan`n`n1. Tag the candidate.`n"; Invoke-Git $Repo @('add', '--', 'delivery/release'); Invoke-Git $Repo @('commit', '-qm', 'release plan')
          Write-RepoFile $Repo 'delivery/release/release-plan.md' "# Release plan`n`n1. Tag the candidate.`n2. Also ship a hotfix.`n"; Invoke-Git $Repo @('commit', '-qam', 'edit release plan') }
    'd' { $p = Join-Path $Repo 'delivery/approvals.md'; [IO.File]::WriteAllText($p, [IO.File]::ReadAllText($p).Replace('waive lint for this release', 'waive lint and unit for this release')); Invoke-Git $Repo @('commit', '-qam', 'amend waiver') }
  }
  $done = { param($i, $t, $o, $ph, $g) $r = @{}; foreach ($x in $g) { $r[$x] = 'passed' }; @{ id = $i; title = $t; owner = $o; phase = $ph; deps = @(); status = 'done'; retries = 0; requiredGates = $g; gateResults = $r } }
  New-RunState -Root $Repo -RunId $id -Phase 'deploy' `
    -Signoff @{ status = 'approved'; artifact = $sha; approvers = @{ product_owner = 'Pat Lee'; security_team = 'Sam Roy'; tech_lead = 'Dana Kim' }; grantedAt = '2026-01-02T10:00:00Z' } `
    -Tasks @((& $done 'T-001' 'Add task' 'ait-backend-dev' 'build' @('build', 'unit')), (& $done 'T-002' 'Acceptance' 'ait-qa-test' 'test' @('acceptance')),
      @{ id = 'T-003'; title = 'Deploy'; owner = 'ait-devops'; phase = 'deploy'; deps = @('T-001', 'T-002'); status = 'pending'; retries = 0; requiredGates = @('pre-deploy', 'smoke', 'rollback-ready'); gateResults = @{} })
}

$prompt = "Use the ait-sdlc-orchestrate skill to resume run 2026-01-02-tasky. It is at Deploy. Do only the resume checks and the pre-deploy sign-off validity check, update state.json accordingly, then stop without deploying anything and report the sign-off status in one line. Don't ask questions."
$check = {
  param($Repo, $Log, $Changed, $Case)
  $s = Read-Json $Repo '.copilot-tracking/2026-01-02-tasky/state.json'
  Expect ($null -ne $s) 'state.json missing or unreadable'
  Expect ((Get-ReplyText $Log) -match '(?i)sign-?off') 'the reply does not report the sign-off status'
    Expect ($Log -match 'git (diff|log|rev-parse|status|cat-file)') 'no evidence the run compared the tree with the release candidate (a no-op cannot pass)'
  Expect ($s.signoff.status -eq $Case.Expect) "signoff.status is '$($s.signoff.status)', expected '$($Case.Expect)'"
  if ($Case.Expect -eq 'approved') { Expect ($Changed -contains '.copilot-tracking/2026-01-02-tasky/state.json') 'state.json was not updated (the check did not run)'; Expect ((Get-ReplyText $Log) -notmatch '(?i)sign-?off\W+(is|was|now|has been)\s+(void|voided|invalid|reset|pending)\b') 'the reply declares the sign-off void' }
  Expect (-not @($Changed | Where-Object { $_ -match '^(src/|delivery/release/)' }).Count) "changed src/ or delivery/release/: $($Changed -join ', ')"
}

@(
  @{ Name = 'signoff-valid-new-records'; Variant = 'a'; Expect = 'approved'; Covers = '1.1.1 §8.2 #14a: appended sign-off + new release file keep sign-off' }
  @{ Name = 'signoff-void-src-change'; Variant = 'b'; Expect = 'pending'; Covers = '1.1.1 §8.2 #14b: a src/ change after the candidate voids sign-off' }
  @{ Name = 'signoff-void-record-edit'; Variant = 'd'; Expect = 'pending'; Covers = '1.1.1 §8.2 #14d (first half): editing an earlier approvals.md line voids sign-off' }
  @{ Name = 'signoff-void-release-edit'; Variant = 'e'; Expect = 'pending'; Covers = '1.1.1 §8.2 #14d (second half): editing an existing delivery/release/ file voids sign-off' }
) | ForEach-Object { $_ + @{ Model = 'gpt-5.6-sol'; Runs = 1; Pass = 1; Setup = $setup; Prompt = $prompt; Check = $check } }
