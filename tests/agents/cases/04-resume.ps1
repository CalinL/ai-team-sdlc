# Resuming a run started on 1.1.0 (spec 1.1.1 §2.4 carry-over, §8.2 #16 resumed part; O2).
# The old run has no state.json.layout and keeps its records in decisions.md. On the first resume the
# sign-off record and waiver are appended verbatim to delivery/approvals.md, marked carried over, and
# committed; decisions.md, changes.md and tasks.md stay untouched. A commit-SHA sign-off on an
# unchanged tree stays valid; an artifact-name sign-off resets to pending.
$setup = {
  param($Repo, $Case)
  $id = '2025-12-01-tasky'
  Write-RepoFile $Repo '.gitignore' ".copilot-tracking/`n"
  Write-RepoFile $Repo 'src/app.js' "export const add = (list, t) => [...list, { t, done: false }];`n"
  Invoke-Git $Repo @('add', '-A'); Invoke-Git $Repo @('commit', '-qm', 'release candidate')
  $artifact = if ($Case.Variant -eq 'sha') { Get-HeadSha $Repo } else { 'tasky-1.0.0' }
  $t = ".copilot-tracking/$id"
  New-RunState -Root $Repo -RunId $id -Phase 'deploy' -Layout $null `
    -Signoff @{ status = 'approved'; artifact = $artifact; approvers = @{ product_owner = 'Pat Lee'; security_team = 'Sam Roy'; tech_lead = 'Dana Kim' }; grantedAt = '2025-12-01T10:00:00Z' } `
    -Tasks @(@{ id = 'T-001'; title = 'Add task'; owner = 'ait-backend-dev'; phase = 'build'; deps = @(); status = 'done'; retries = 0; requiredGates = @('build', 'unit'); gateResults = @{ build = 'passed'; unit = 'passed' } },
      @{ id = 'T-002'; title = 'Deploy'; owner = 'ait-devops'; phase = 'deploy'; deps = @('T-001'); status = 'pending'; retries = 0; requiredGates = @('pre-deploy', 'smoke', 'rollback-ready'); gateResults = @{} })
  Write-RepoFile $Repo "$t/decisions.md" @"
# Decisions — $id

## D-001 Storage: SQLite (2025-12-01)
Use SQLite via better-sqlite3; JSON files rejected (no concurrency).

## Waiver — T-001 lint (2025-12-01T09:00Z)
Tech Lead Dana Kim, verbatim: "No linter yet; waive lint for this release."

## Sign-off — $artifact (2025-12-01T10:00Z)
- Product Owner Pat Lee: "Approved."
- Security Team Sam Roy: "No open findings, approved."
- Tech Lead Dana Kim: "Approved to ship."
"@
  Write-RepoFile $Repo "$t/changes.md" "# Changes`n`n- T-001: src/app.js`n"
  Write-RepoFile $Repo "$t/tasks.md" "| id | title | owner | phase | deps | acceptance | requiredGates | gateResults | status |`n|---|---|---|---|---|---|---|---|---|`n| T-001 | Add task | ait-backend-dev | build | | adds | build, unit | passed | done |`n"
}

$prompt = "Use the ait-sdlc-orchestrate skill to resume run 2025-12-01-tasky. It is at Deploy. Do only the resume steps (step 0) and the pre-deploy sign-off validity check, update state.json accordingly, then stop without deploying anything and report the sign-off status in one line. Don't ask questions."
$check = {
  param($Repo, $Log, $Changed, $Case)
  $t = '.copilot-tracking/2025-12-01-tasky'
  $ap = Read-Text $Repo 'delivery/approvals.md'
  $s = Read-Json $Repo "$t/state.json"
  Expect (Test-Committed $Repo 'delivery/approvals.md') 'delivery/approvals.md is not committed'
  Expect ($ap -match '(?i)carried over') 'records are not marked carried over'
  Expect ($ap -match 'waive lint for this release' -and $ap -match 'No open findings, approved\.' -and $ap -match 'Approved to ship\.') 'sign-off record or waiver not carried over verbatim'
  Expect ($ap -notmatch '(?i)sqlite') 'a decision (not an approval record) was carried into approvals.md'
  Expect (-not @($Changed | Where-Object { $_ -match "^$([regex]::Escape($t))/(decisions|changes|tasks)\.md$" }).Count) 'the old decisions.md, changes.md or tasks.md was modified'
  Expect ($s.signoff.status -eq $Case.Expect) "signoff.status is '$($s.signoff.status)', expected '$($Case.Expect)'"
  Expect (-not @($Changed | Where-Object { $_ -match '^(src/|delivery/release/)' }).Count) 'deployed or changed src/'
}

@(
  @{ Name = 'resume-110-carryover-sha'; Variant = 'sha'; Expect = 'approved'; Covers = '1.1.1 §2.4/§8.2 #16 (resume part, not new decisions): carry-over; SHA sign-off on unchanged tree stays valid' }
  @{ Name = 'resume-110-carryover-name'; Variant = 'name'; Expect = 'pending'; Covers = '1.1.1 §2.4/§8.2 #16 (resume part, not new decisions): carry-over; artifact-name sign-off resets to pending' }
) | ForEach-Object { $_ + @{ Model = 'gpt-5.6-sol'; Runs = 1; Pass = 1; Setup = $setup; Prompt = $prompt; Check = $check } }
