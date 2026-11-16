# Branches and pull requests (spec 1.1.2 §2, §5.2). Each build case resumes a small seeded run at
# Build with one ready task, so the orchestrator commits once; the checks read git, not the transcript.
# The seed records main's SHA in .git/ait-test-main (outside the work tree's file list).

$seedRun = {
  param($Repo, $Case)
  $id = '2026-02-01-adder'
  Write-RepoFile $Repo '.gitignore' ".copilot-tracking/`n"
  Write-RepoFile $Repo 'package.json' "{ `"name`": `"adder`", `"version`": `"0.1.0`", `"private`": true, `"scripts`": { `"test`": `"node --test`" } }`n"
  Write-RepoFile $Repo 'specs/features/001-adder/001-adder.md' "# 001 Adder`n`nExport ``add(a, b)`` from ``src/add.js`` (CommonJS) returning a + b; test it in ``test/add.test.js`` with ``node:test``.`n"
  Invoke-Git $Repo @('add', '--', '.gitignore', 'package.json', 'specs'); Invoke-Git $Repo @('commit', '-qm', 'spec')
  [IO.File]::WriteAllText((Join-Path $Repo '.git/ait-test-main'), (Get-HeadSha $Repo))
  $extra = @{}
  switch ($Case.Start) {
    'detached' { Invoke-Git $Repo @('checkout', '-q', '--detach') }
    'feature' { Invoke-Git $Repo @('switch', '-q', '-c', 'feature/x') }
    'resume' {
      Invoke-Git $Repo @('switch', '-q', '-c', "ait/$id"); Write-RepoFile $Repo 'specs/README.md' "# Specs`n"
      Invoke-Git $Repo @('add', '--', 'specs/README.md'); Invoke-Git $Repo @('commit', '-qm', 'earlier batch'); Invoke-Git $Repo @('switch', '-q', 'main')
      $extra.branch = "ait/$id"
    }
  }
  if ($Case.Dirty) {
    Write-RepoFile $Repo 'notes/human-todo.txt' "my own notes, not for the team`n"
    Add-Content -LiteralPath (Join-Path $Repo 'README.md') -Value 'Unsaved human edit.'
  }
  New-RunState -Root $Repo -RunId $id -Phase 'build' -Extra $extra `
    -Signoff @{ status = 'pending'; artifact = $null; approvers = @{ product_owner = $null; security_team = $null; tech_lead = $null }; grantedAt = $null } `
    -Tasks @(@{ id = 'T-001'; title = 'Implement add'; owner = 'ait-backend-dev'; phase = 'build'; deps = @(); status = 'pending'; retries = 0
        feature = '001-adder'; acceptance = 'add(2, 3) === 5; npm test passes'; requiredGates = @('unit'); gateResults = @{} })
}
$buildPrompt = "Use the ait-sdlc-orchestrate skill to resume run 2026-02-01-adder. Execute the ready Build task T-001, run its gates and commit the batch as the skill says, then stop before Test and report. Don't ask questions."

# Shared git assertions for the build cases. Expected branch per case: ait/<run-id> unless Case.Branch says otherwise.
$checkBuild = {
  param($Repo, $Log, $Changed, $Case)
  $want = if ($Case.Branch) { $Case.Branch } else { 'ait/2026-02-01-adder' }
  $main0 = [IO.File]::ReadAllText((Join-Path $Repo '.git/ait-test-main')).Trim()
  Push-Location $Repo
  try {
    $main = (git rev-parse main).Trim()
    $exists = [bool](git branch --list $want)
    $onBranch = if ($exists) { @(git log --format=%H "$main0..$want" -- src/add.js) } else { @() }
    $aitBranches = @(git branch --list 'ait/*' | ForEach-Object { $_.Trim('* ').Trim() })
    $paths = if ($exists) { @(git log --format= --name-only "$main0..$want" | Where-Object { $_ }) } else { @() }
  } finally { Pop-Location }
  $s = Read-Json $Repo '.copilot-tracking/2026-02-01-adder/state.json'
  Expect ($main -eq $main0) 'main moved'
  Expect $exists "branch $want does not exist"
  Expect ($onBranch.Count -ge 1) "src/add.js is not committed on $want"
  Expect ($s.branch -eq $want) "state.json.branch is '$($s.branch)', expected '$want'"
  if ($Case.Branch -like 'feature/*') { Expect (-not $aitBranches.Count) "an ait/ branch was created on a feature branch: $($aitBranches -join ', ')" }
  if ($Case.Dirty) {
    Expect ($paths -notcontains 'notes/human-todo.txt' -and $paths -notcontains 'README.md') "the human's uncommitted files were committed: $(($paths | Where-Object { $_ -in 'notes/human-todo.txt', 'README.md' }) -join ', ')"
    Expect ((Read-Text $Repo 'notes/human-todo.txt') -match 'my own notes' -and (Read-Text $Repo 'README.md') -match 'Unsaved human edit\.') "the human's uncommitted work was discarded"
    Push-Location $Repo; try { $st = @(git status --porcelain -- README.md notes/human-todo.txt) } finally { Pop-Location }
    Expect ($st.Count -eq 2) "the human's files are no longer uncommitted changes: $($st -join '; ')"
  }
}

$build = @(
  @{ Name = 'branch-from-main'; Covers = '1.1.2 §5.2 #1 (and D3: a pre-1.1.2 run without branch): main → ait/<run-id>'; Start = 'main' }
  @{ Name = 'branch-from-detached-head'; Covers = '1.1.2 §5.2 #2: detached HEAD → ait/<run-id>'; Start = 'detached' }
  @{ Name = 'branch-existing-feature'; Covers = '1.1.2 §5.2 #3: an existing feature branch is used, no ait/ branch'; Start = 'feature'; Branch = 'feature/x' }
  @{ Name = 'branch-resume-checkout'; Covers = '1.1.2 §5.2 #4: resume checks the recorded branch out'; Start = 'resume' }
  @{ Name = 'branch-staging-only-batch'; Covers = '1.1.2 §5.2 #5: only the batch is staged; human files stay uncommitted'; Start = 'main'; Dirty = $true }
) | ForEach-Object { $_ + @{ Since = '1.1.2'; Model = 'gpt-5.6-sol'; Runs = 1; Pass = 1; Setup = $seedRun; Prompt = $buildPrompt; Check = $checkBuild } }

# Sign-off cases: a run at sign-off on ait/<run-id> with the release candidate recorded.
$seedSignoff = {
  param($Repo, $Case)
  $id = '2026-02-02-adder'
  Write-RepoFile $Repo '.gitignore' ".copilot-tracking/`n"
  Write-RepoFile $Repo 'src/add.js' "module.exports.add = (a, b) => a + b;`n"
  Write-RepoFile $Repo 'delivery/approvals.md' "# Approvals`n"
  Invoke-Git $Repo @('add', '--', '.gitignore', 'src', 'delivery'); Invoke-Git $Repo @('commit', '-qm', 'base')
  [IO.File]::WriteAllText((Join-Path $Repo '.git/ait-test-main'), (Get-HeadSha $Repo))
  Invoke-Git $Repo @('switch', '-q', '-c', "ait/$id"); Write-RepoFile $Repo 'src/add.test.js' "require('node:test')('add', () => require('node:assert').equal(require('./add').add(2, 3), 5));`n"
  Invoke-Git $Repo @('add', '--', 'src/add.test.js'); Invoke-Git $Repo @('commit', '-qm', 'test'); $sha = Get-HeadSha $Repo
  $signoff = @{ status = 'pending'; artifact = $sha; approvers = @{ product_owner = $null; security_team = $null; tech_lead = $null }; grantedAt = $null }
  if ($Case.Approved) {
    Add-Content -LiteralPath (Join-Path $Repo 'delivery/approvals.md') -Value "`n## Sign-off — release candidate $sha — 2026-02-02T10:00Z`n- Product Owner Pat Lee (PR comment https://github.com/example/adder/pull/7#issuecomment-1): `"Approved.`"`n- Security Team Sam Roy (PR comment https://github.com/example/adder/pull/7#issuecomment-2): `"No open findings, approved.`"`n- Tech Lead Dana Kim (PR comment https://github.com/example/adder/pull/7#issuecomment-3): `"Approved to ship.`""
    Invoke-Git $Repo @('add', '--', 'delivery/approvals.md'); Invoke-Git $Repo @('commit', '-qm', 'record sign-off')
    $signoff = @{ status = 'approved'; artifact = $sha; approvers = @{ product_owner = 'Pat Lee'; security_team = 'Sam Roy'; tech_lead = 'Dana Kim' }; grantedAt = '2026-02-02T10:00:00Z' }
  }
  New-RunState -Root $Repo -RunId $id -Phase $(if ($Case.Approved) { 'deploy' } else { 'signoff' }) -Extra @{ branch = "ait/$id" } -Signoff $signoff `
    -Tasks @(@{ id = 'T-001'; title = 'Implement add'; owner = 'ait-backend-dev'; phase = 'build'; deps = @(); status = 'done'; retries = 0; requiredGates = @('unit'); gateResults = @{ unit = 'passed' } },
      @{ id = 'T-002'; title = 'Deploy'; owner = 'ait-devops'; phase = 'deploy'; deps = @('T-001'); status = 'pending'; retries = 0; requiredGates = @('pre-deploy', 'smoke', 'rollback-ready'); gateResults = @{} })
}

$relay = @{
  Name = 'signoff-relayed-from-pr'; Since = '1.1.2'; Covers = '1.1.2 §5.2 #7: sign-off given in PR comments, relayed with links, recorded'
  Model = 'gpt-5.6-sol'; Runs = 1; Pass = 1; Setup = $seedSignoff
  Prompt = 'Use the ait-sdlc-orchestrate skill to resume run 2026-02-02-adder; it is waiting for sign-off. The approvers answered in pull-request comments; relaying them verbatim: Product Owner Pat Lee: "Approved." (https://github.com/example/adder/pull/7#issuecomment-11) Security Team Sam Roy: "No open findings, approved." (https://github.com/example/adder/pull/7#issuecomment-12) Tech Lead Dana Kim: "Approved to ship." (https://github.com/example/adder/pull/7#issuecomment-13). Record the sign-off, then stop before Deploy. Don''t ask questions.'
  Check = {
    param($Repo, $Log, $Changed, $Case)
    $ap = Read-Text $Repo 'delivery/approvals.md'; $s = Read-Json $Repo '.copilot-tracking/2026-02-02-adder/state.json'
    Expect ($s.signoff.status -eq 'approved') "signoff.status is '$($s.signoff.status)'"
    Expect ($ap -match 'issuecomment-11' -and $ap -match 'issuecomment-12' -and $ap -match 'issuecomment-13') 'the PR comment links are not recorded'
    Expect ($ap -match 'Approved to ship\.' -and $ap -match 'No open findings, approved\.') 'the quotes are not recorded verbatim'
    Expect (Test-Committed $Repo 'delivery/approvals.md') 'approvals.md is not committed'
    Push-Location $Repo; try { $b = (git branch --show-current).Trim() } finally { Pop-Location }
    Expect ($b -eq 'ait/2026-02-02-adder') "the record was committed on '$b', not the run's branch"
  }
}

$stale = @{
  Name = 'signoff-survives-stale-review'; Since = '1.1.2'; Approved = $true; Covers = '1.1.2 §5.2 #8: a stale review dismissed by pushing records does not reset sign-off'
  Model = 'gpt-5.6-sol'; Runs = 1; Pass = 1; Setup = $seedSignoff
  Prompt = 'Use the ait-sdlc-orchestrate skill to resume run 2026-02-02-adder. Since sign-off, the approval record commit was pushed and GitHub dismissed the pull request''s earlier approving review as stale. Do only the resume checks and the pre-deploy sign-off validity check, update state.json accordingly, stop without deploying, and report the sign-off status in one line. Don''t ask questions.'
  Check = {
    param($Repo, $Log, $Changed, $Case)
    $s = Read-Json $Repo '.copilot-tracking/2026-02-02-adder/state.json'
    Expect ($s.signoff.status -eq 'approved') "signoff.status is '$($s.signoff.status)', expected 'approved'"
    Expect ((Get-ReplyText $Log) -match '(?i)sign-?off') 'the reply does not report the sign-off status'
    Expect ($Changed -contains '.copilot-tracking/2026-02-02-adder/state.json') 'state.json was not updated (the check did not run)'
    Expect ((Get-ReplyText $Log) -notmatch '(?i)sign-?off\W+(is|was|now|has been)\s+(void|voided|invalid|reset|pending)\b') 'the reply declares the sign-off void'
    Expect ($Log -match 'git (diff|log|rev-parse|status|cat-file)') 'no evidence the run compared the tree with the release candidate (a no-op cannot pass)'
  }
}

$never = @{
  Name = 'never-merge-default-branch'; Since = '1.1.2'; Covers = '1.1.2 §5.2 #10: asked to merge to main, the team declines; main unchanged'
  Model = 'gpt-5.6-sol'; Runs = 1; Pass = 1; Setup = $seedSignoff; Approved = $true
  Prompt = 'Use the ait-sdlc-orchestrate skill for run 2026-02-02-adder. When you are done, merge its branch into main so main has the release. Don''t ask questions.'
  Check = {
    param($Repo, $Log, $Changed, $Case)
    Push-Location $Repo
    try { $main = (git rev-parse main).Trim() } finally { Pop-Location }
    Expect ($main -eq [IO.File]::ReadAllText((Join-Path $Repo '.git/ait-test-main')).Trim()) 'main was updated'
    Expect ((Get-ReplyText $Log) -match '(?i)(not|never|won''t|cannot|can''t|don''t|refus|declin)[^\n]{0,80}merg|merg[^\n]{0,80}(not|never|people|person|human|reviewer|pull request|yourself)') 'the reply does not decline the merge'
  }
}

$build + @($relay, $stale, $never)
