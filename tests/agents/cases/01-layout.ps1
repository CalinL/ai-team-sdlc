# Layout cases: where work products land (spec 1.1.1 §2.4, §8.2 #5, #6, #12).
$tasky = 'Tasky, a small to-do list web app'

@(
  @{
    Name   = 'layout-placement-weak'
    Covers = '1.1.1 §8.2 #12 (weak model places 4 mapped artifacts, writes the unmapped one nowhere)'
    Model  = 'claude-haiku-4.5'; Runs = 5; Pass = 4
    Prompt = "Use the ait-artifact-layout skill. Product: $tasky. Write these five work products into this repository, each where the layout says it goes, then commit what you wrote: (1) a one-page PRD; (2) the implementation spec for its first feature, 'add task'; (3) a decision record choosing SQLite for storage; (4) a single-file clickable HTML prototype of the task list; (5) a short launch announcement email for customers. Work without asking questions during the work."
    Check  = {
      param($Repo, $Log, $Changed)
      $spec = @($Changed | Where-Object { $_ -match '^specs/features/(\d{3}-[a-z0-9-]+)/(\d{3}-[a-z0-9-]+)\.md$' -and $Matches[1] -eq $Matches[2] })
      $adr = @($Changed | Where-Object { $_ -match '^architecture/adr/\d{3}-[a-z0-9-]+\.md$' })
      $allowed = '^(specs/prd\.md|specs/README\.md|specs/features/\d{3}-[a-z0-9-]+/(stories\.md|tasks\.md|\d{3}-[a-z0-9-]+\.md)|specs/ui/prototype-v\d+\.html|architecture/adr/\d{3}-[a-z0-9-]+\.md)$'   # the four mapped artifacts (+ index, stories, plan)
      $stray = @($Changed | Where-Object { $_ -notmatch $allowed })
      Expect ($Changed -contains 'specs/prd.md') 'no specs/prd.md'
      Expect ($spec.Count -ge 1) 'no folder-named feature spec under specs/features/'
      Expect ($adr.Count -ge 1) 'no decision record in architecture/adr/'
      Expect (@($adr | Where-Object { (Read-Text $Repo $_) -match 'Proposed' }).Count -ge 1) 'decision record is not Proposed'
      Expect (@($Changed | Where-Object { $_ -match '^specs/ui/prototype-v\d+\.html$' }).Count -ge 1) 'no specs/ui/prototype-v<N>.html'
      Expect (-not $stray.Count) "unmapped or misplaced files: $($stray -join ', ')"
      Expect ((Get-ReplyText $Log) -match '(?is)(launch|announcement|email).{0,400}(where|which (folder|location|path)|destination|no (row|home)|not (written|saved|placed))|(where|destination).{0,200}(launch|announcement|email)') 'reply does not ask where the email goes'
    }
  }
  @{
    Name   = 'layout-host-rules'
    Covers = '1.1.1 §2.4 order 3, §8.2 #6 (host AGENTS.md beats the defaults)'
    Model  = 'gpt-5.6-sol'; Runs = 1; Pass = 1
    Files  = @{ 'AGENTS.md' = "# Repo rules`n`nAll specifications, including the PRD and feature specs, go in ``design/`` (never ``specs/``).`n" }
    Prompt = "Use the ait-artifact-layout skill and write a one-page PRD for $tasky in this repository, then commit it. Don't ask questions."
    Check  = {
      param($Repo, $Log, $Changed)
      Expect (@($Changed | Where-Object { $_ -match '^design/.+\.md$' }).Count -ge 1) 'no PRD under design/'
      Expect (-not @($Changed | Where-Object { $_ -match '^specs/' }).Count) 'wrote under specs/ despite the host rule'
    }
  }
  @{
    Name   = 'layout-explicit-folder'
    Covers = '1.1.1 §2.4 order 1, §8.2 #6 (explicit output folder on /product-prototype)'
    Model  = 'gpt-5.6-sol'; Runs = 1; Pass = 1
    Prompt = "Use the ait-product-prototype skill with output folder prototypes/tasky/. Build a tiny single-file clickable HTML prototype of the task list of $tasky (add a task, tick it done). Keep it small; skip browser verification and reviews. Don't ask questions."
    Check  = {
      param($Repo, $Log, $Changed)
      Expect (@($Changed | Where-Object { $_ -match '^prototypes/tasky/.+\.html$' }).Count -ge 1) 'no prototype under prototypes/tasky/'
      Expect (-not @($Changed | Where-Object { $_ -match '^(specs/ui|docs)/' }).Count) 'wrote into specs/ui/ or docs/ despite the explicit folder'
    }
  }
  @{
    Name   = 'layout-version-series'
    Covers = '1.1.1 §2.4 order 5, §8.2 #5 (v2 beside an existing docs/ v1, nothing moved)'
    Model  = 'gpt-5.6-sol'; Runs = 1; Pass = 1
    Files  = @{ 'docs/tasky-prototype-v1.html' = "<!doctype html><title>Tasky v1</title><h1>Tasky</h1><ul><li><input type=checkbox> Buy milk</li></ul>`n" }
    Prompt = "Use the ait-product-prototype skill to make version 2 of the Tasky prototype: the same screen plus a 'Clear completed' button. Keep it a single small HTML file; skip browser verification and reviews. Don't ask questions."
    Check  = {
      param($Repo, $Log, $Changed)
      Expect ($Changed -contains 'docs/tasky-prototype-v2.html') 'v2 not written beside v1 as docs/tasky-prototype-v2.html'
      Expect ($Changed -notcontains 'docs/tasky-prototype-v1.html' -and (Test-Path (Join-Path $Repo 'docs/tasky-prototype-v1.html'))) 'v1 was changed or moved'
      Expect (-not @($Changed | Where-Object { $_ -match '^specs/ui/' }).Count) 'started a new series in specs/ui/'
    }
  }
)
