# Record cases: delivery/approvals.md holds only human-sourced records; decisions become ADRs
# (spec 1.1.1 §2.3 rules 1–2, ait-scribe; regression for the 1.1.1 E2E defect fixed in af4417d).
$run = '2026-01-01-tasky'

@(
  @{
    Name   = 'scribe-human-only'
    Covers = '1.1.1 rules 1–2: Scribe writes ADRs + human waivers; agent gate results never reach approvals.md'
    Model  = 'gpt-5.6-sol'; Runs = 1; Pass = 1; Agent = 'ai-team-sdlc:ait-scribe'
    Files  = @{
      '.gitignore'            = ".copilot-tracking/`n"
      'specs/prd.md'          = "# Tasky PRD`n`n- REQ-1 Add a task.`n"
      'delivery/approvals.md' = "# Approvals`n"
    }
    Setup  = {
      param($Repo)
      New-RunState -Root $Repo -RunId '2026-01-01-tasky' -Phase 'test' -Signoff @{ status = 'pending'; artifact = $null; approvers = @{ product_owner = $null; security_team = $null; tech_lead = $null }; grantedAt = $null } `
        -Tasks @(@{ id = 'T-001'; title = 'Add task API'; owner = 'ait-backend-dev'; phase = 'build'; status = 'done'; requiredGates = @('build', 'unit'); gateResults = @{ build = 'passed'; unit = 'passed' } })
      $inbox = '.copilot-tracking/2026-01-01-tasky/inbox'
      Write-RepoFile $Repo "$inbox/20260101T100000Z-ait-backend-dev-T-001.md" "### Result — T-001 · ait-backend-dev`n- Status: done`n- Files: src/tasks.js`n- Gate: build passed; unit passed (12 tests)`n- Decisions: store tasks in SQLite via better-sqlite3 (single file, no server); considered JSON files (rejected: no concurrency).`n- Next: orchestrator`n"
      Write-RepoFile $Repo "$inbox/20260101T110000Z-ait-qa-test-T-002.md" "### Result — T-002 · ait-qa-test`n- Status: done`n- Files: delivery/results/qa-T-002.md`n- Gate: acceptance passed (5/5 criteria)`n- Decisions: none`n- Next: orchestrator`n"
      Write-RepoFile $Repo "$inbox/20260101T120000Z-orchestrator-T-003.md" "### Waiver — T-003 · lint`nThe Tech Lead (Dana Kim) waived the required ``lint`` gate for T-003 in the chat on 2026-01-01T11:58Z, verbatim: `"No linter is set up in this repo yet; I waive lint for this release.`"`n"
    }
    Prompt = "Process the unprocessed inbox of run .copilot-tracking/$run/ now. Don't ask questions."
    Check  = {
      param($Repo, $Log, $Changed)
      $ap = Read-Text $Repo 'delivery/approvals.md'
      $adr = @($Changed | Where-Object { $_ -match '^architecture/adr/\d{3}-[a-z0-9-]+\.md$' })
      Expect ($ap -match 'I waive lint for this release') 'the human waiver is not in delivery/approvals.md verbatim'
      Expect ($ap -notmatch '(?i)(build|unit|acceptance)[^\n]{0,20}passed|12 tests|5/5') 'agent gate results were written to delivery/approvals.md'
      Expect ($ap -notmatch '(?i)sqlite') 'a decision was written to delivery/approvals.md'
      Expect ($adr.Count -ge 1 -and (Read-Text $Repo $adr[0]) -match '(?i)sqlite' -and (Read-Text $Repo $adr[0]) -match 'Proposed') 'no Proposed SQLite decision record in architecture/adr/'
      Expect (-not @($Changed | Where-Object { $_ -match '(^|/)(decisions|changes)\.md$' }).Count) 'wrote decisions.md or changes.md'
      Expect (-not @($Changed | Where-Object { $_ -match '/(state\.json|plan\.md)$' }).Count) 'edited orchestrator-owned state.json or plan.md'
    }
  }
)
