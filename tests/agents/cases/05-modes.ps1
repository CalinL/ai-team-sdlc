# Mode cases: contract-mode validation and activation, and that default mode applies no contract rule
# (spec 1.1.0 §1 R2/§7 test 10b, ait-contract-mode §1 Activation and When NOT to use).
@(
  @{
    Name   = 'contract-invalid-config-stops'
    Covers = 'ait-contract-mode §1: an invalid .github/ai-sdlc.yml stops the run and lists every error'
    Model  = 'gpt-5.6-sol'; Runs = 1; Pass = 1
    Files  = @{
      '.gitignore'          = ".copilot-tracking/`n"
      '.github/ai-sdlc.yml' = "contract:`n  brief: ../shared/brief.md`n  stages:`n    prototype: wireframe`n"
      'specs/prd.md'        = "# Tasky PRD`n`n- REQ-1 Add a task.`n"
    }
    Prompt = 'Use the ait-sdlc-orchestrate skill. Run the full SDLC for this repository. Don''t ask questions.'
    Check  = {
      param($Repo, $Log, $Changed)
      Expect (-not @($Changed | Where-Object { $_ -notmatch '^\.copilot-tracking/' }).Count) "the run went on and wrote: $(($Changed | Where-Object { $_ -notmatch '^\.copilot-tracking/' }) -join ', ')"
      Expect ($Log -match '(?i)\.\./shared|(contain|has|includes|uses|with)[^\n]{0,30}\.\.') 'the ".." brief path error is not reported'
      Expect ($Log -match 'wireframe') 'the stages.prototype error is not reported'
    }
  }
  @{
    Name   = 'contract-skill-inactive-in-default'
    Covers = 'ait-contract-mode When NOT to use: no contract block, no contract rule applied'
    Model  = 'gpt-5.6-sol'; Runs = 1; Pass = 1
    Files  = @{ 'specs/prd.md' = "# Tasky PRD`n`n- REQ-1 Add a task.`n" }
    Prompt = 'Use the ait-contract-mode skill to deliver specs/prd.md. First say in one sentence whether contract mode applies in this repository and why; if it does not, stop there. Don''t ask questions.'
    Check  = {
      param($Repo, $Log, $Changed)
      Expect (-not $Changed.Count) "files were written: $($Changed -join ', ')"
      Expect ($Log -match '(?is)(not|n''t|no)\b.{0,80}(apply|active|ai-sdlc\.yml|contract:)') 'reply does not say contract mode is inactive'
    }
  }
  @{
    Name   = 'default-mode-gates-weak'
    Covers = '1.1.0 §7 10b (weak model): default mode runs only the requested gates, no contract gate'
    Model  = 'claude-haiku-4.5'; Runs = 5; Pass = 4
    Files  = @{ 'package.json' = "{ `"name`": `"tasky`", `"version`": `"1.0.0`", `"scripts`": { `"build`": `"node -e 0`", `"lint`": `"node -e 0`", `"test`": `"node -e 0`" } }`n" }
    Prompt = 'Use the ait-quality-gates skill. Task T-001 in this repository has requiredGates build, lint, unit. Answer with a numbered list of the gates you would run for it, in order, one per line, and nothing else. Don''t run anything and don''t write files.'
    Check  = {
      param($Repo, $Log, $Changed)
      $items = @(($Log -split "`r?`n") | Where-Object { $_ -match '^\s*\d+[.)]\s' })
      $list = ($items -join "`n").ToLowerInvariant()
      Expect (-not $Changed.Count) "files were written: $($Changed -join ', ')"
      Expect ($items.Count -ge 3) 'no numbered gate list in the reply'
      Expect ($list -notmatch '(?i)path[- ]check|spec-conformance|release-acceptance|conformance|baseline|protected|external gate') "a contract-only gate is listed: $list"
      $b = $list.IndexOf('build'); $l = $list.IndexOf('lint'); $u = [Math]::Max($list.IndexOf('unit'), $list.IndexOf('test'))
      Expect ($b -ge 0 -and $l -gt $b -and $u -gt $l) "build, lint, unit not listed in order: $list"
    }
  }
)
