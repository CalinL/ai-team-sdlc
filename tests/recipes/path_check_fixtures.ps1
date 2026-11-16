# Tier 2 — path-check fixtures (PowerShell 7 and Windows PowerShell 5.1), run against the recipe as
# published in the plugin reference. Same 27 fixtures as path_check_fixtures.sh.
# Usage: pwsh -File tests/recipes/path_check_fixtures.ps1 -Lib <lib.ps1> -Work <work-dir>
param([Parameter(Mandatory)][string]$Lib, [Parameter(Mandatory)][string]$Work)
$ErrorActionPreference = 'Continue'
. $Lib
New-Item -ItemType Directory -Force -Path $Work | Out-Null
$Work = (Resolve-Path $Work).Path
$env:GIT_CEILING_DIRECTORIES = $Work   # git never walks up into a parent repository
$script:Ok = 0; $script:Bad = 0
$W = @('delivery/brief.md', 'specs/prd.md', '.github/ai-sdlc.yml', 'delivery/approvals.md', 'specs/ui/ACCEPTED.md', 'delivery/conformance/*.md', 'delivery/results/acceptance-*.md')
$B = '.copilot-tracking/run/baselines/T-001'

function Put($p, $s) {
  $d = Split-Path $p; if ($d) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
  [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p), $s)
}
function Setup {
  Set-Location $Work; if (Test-Path r) { Get-ChildItem r -Recurse -Force | ForEach-Object { $_.Attributes = 'Normal' }; Remove-Item -Recurse -Force r }
  New-Item -ItemType Directory r | Out-Null; Set-Location r
  git init -q; git config user.name t; git config user.email t@example.com; git config core.autocrlf false; git config core.ignorecase false
  Put '.gitignore' ".copilot-tracking/`ndelivery/brief.md`n"; Put '.github/ai-sdlc.yml' "contract:`n  brief: delivery/brief.md`n"
  Put 'delivery/brief.md' "# Brief`n"; Put 'specs/prd.md' "# PRD`n- REQ-1`n"; Put 'architecture/adr/003-x.md' "# ADR-003`nStatus: Accepted`n"
  Put 'architecture/overview.md' "# Overview`n"; Put 'delivery/approvals.md' "# Approvals`n- sign-off`n"; Put 'src/app.js' "a`n"; Put 'src/dirty.js' "keep`n"
  git add -A; git commit -qm base; Put 'src/dirty.js' "dirty before baseline`n"
  $script:Watch = $W
  $script:Cfg = @{ Dir = $B; Frozen = @(); Protected = @('architecture/'); DecisionsDir = 'architecture/adr/'; Proposed = 'Proposed'
    Inputs = @('delivery/brief.md', 'specs/prd.md', '.github/ai-sdlc.yml', 'delivery/approvals.md')
    Gates = @('specs/ui/ACCEPTED.md', 'delivery/conformance/*.md', 'delivery/results/acceptance-*.md'); Command = '' }
}
function Base { Invoke-PathCheck -Mode baseline -Dir $B -Watch $script:Watch }
function Run($name, $expected) {
  $cfg = $script:Cfg
  $res = @(Invoke-PathCheck -Mode changed -Dir $B -Watch $script:Watch | Test-PathCheck @cfg)
  $got = if (@($res | Where-Object { -not $_.Pass }).Count) { 'fail' } else { 'pass' }
  if ($got -eq $expected) { $script:Ok++; $s = 'OK' } else { $script:Bad++; $s = 'BAD' }
  '{0,-4} {1,-72} expected={2,-4} got={3,-4} {4}' -f $s, $name, $expected, $got, (($res | ForEach-Object { "$(if ($_.Pass) {'pass'} else {'FAIL'}) $($_.Rule) $($_.Path)" }) -join '; ')
}
$exit = if ($PSVersionTable.PSEdition -eq 'Desktop' -or $IsWindows) { 'cmd /c exit 1' } else { 'sh -c "exit 1"' }

Setup; Base; Put 'delivery/results/qa-001.md' 'r'; Run '01 adds delivery/results/qa-001.md' pass
Setup; Base; Put 'delivery/results/acceptance-abc123.md' 'r'; Run '02 adds delivery/results/acceptance-abc123.md' fail
Setup; Base; Put 'delivery/conformance/001-x.md' 'r'; Run '03 adds delivery/conformance/001-x.md' fail
Setup; Base; Put 'specs/ui/ACCEPTED.md' 'r'; Run '04 adds specs/ui/ACCEPTED.md' fail
Setup; Base; Add-Content delivery/brief.md 'edited'; Run '05 edits gitignored delivery/brief.md' fail
Setup; Base; Add-Content specs/prd.md '- REQ-2'; git commit -qam prd; Run '06 commits an edit to specs/prd.md' fail
Setup; Base; Remove-Item .github/ai-sdlc.yml; Run '07 deletes .github/ai-sdlc.yml' fail
Setup; Base; Put 'architecture/adr/014-cache.md' "# ADR-014`nStatus: Proposed`n"; Run '08 adds Proposed architecture/adr/014-cache.md' pass
Setup; Base; Add-Content architecture/adr/003-x.md 'more'; Run '09 edits Accepted architecture/adr/003-x.md' fail
Setup; Base; Put 'architecture/threat-model.md' 't'; Run '10 adds architecture/threat-model.md' fail
Setup; $script:Cfg.DecisionsDir = 'delivery/'; Base; Put 'delivery/results/acceptance-v1.md' "status: Proposed`n"; Run '11 decisions.dir=delivery/, adds Proposed acceptance-v1.md' fail
Setup; Base; Run '12 dirty-at-baseline file left alone' pass
Setup; Base; Add-Content delivery/approvals.md '- waiver'; Run '13 appends a waiver to delivery/approvals.md' fail
Setup; $script:Cfg.Command = $exit; Base; Run '14 no changes, path_check exits 1' fail
Setup; $script:Cfg.Command = $exit; Base; Put 'architecture/adr/015-x.md' "# ADR-015`nStatus: Proposed`n"; Run '15 adds Proposed adr/015-x.md, path_check exits 1' fail
Setup; $script:Cfg.Frozen = @('./tests/contract/'); Base; Put 'tests/contract/eval.json' 'x'; Run '16 frozen ./tests/contract/, adds tests/contract/eval.json' fail
Setup; Add-Content .gitignore 'delivery receipts/'; git commit -qam ign; $script:Cfg.Gates += 'delivery receipts/*.md'; $script:Watch = $W + 'delivery receipts/*.md'
Put 'delivery receipts/001-x.md' 'old'; Base; Put 'delivery receipts/001-x.md' 'new'; Put 'delivery receipts/002-y.md' 'r'; Run '17 gitignored gate folder with a space: edits and adds receipts' fail
Setup; $script:Cfg.Proposed = 'Proposed (unapproved)'; Base; Put 'architecture/adr/016-x.md' "# ADR-016`nStatus: Proposed (unapproved)`n"; Run "18 proposed_status 'Proposed (unapproved)', adds such a record" pass
Setup; git checkout -q -- src/dirty.js; Base; Put 'delivery/results/qa-002.md' 'r'; Run '19 clean tree at baseline, adds delivery/results/qa-002.md' pass
Setup; git config core.ignorecase true; $script:Cfg.Protected = @('Architecture/'); Base; Put 'architecture/threat-model.md' 't'; Run '20 protected Architecture/ (ignorecase), adds architecture/threat-model.md' fail
Setup; $script:Cfg.Frozen = @('.//tests/contract/'); Base; Put 'tests/contract/eval.json' 'x'; Run '21 frozen .//tests/contract/, adds tests/contract/eval.json' fail
Setup; git config core.ignorecase true; Add-Content .gitignore 'delivery/results/'; git commit -qam ign; Base; Put 'delivery/results/ACCEPTANCE-abc.md' 'r'; Run '22 ignorecase, gitignored results/, adds ACCEPTANCE-abc.md' fail
Setup; Base; Put 'architecture/adr/017-x.md' "# ADR-017`nstatus: Accepted`nStatusProposed`n"; Run "23 new record 'status: Accepted' + line 'StatusProposed'" fail
Setup; Add-Content .gitignore 'delivery/results/'; git commit -qam ign; Put 'delivery/results/acceptance-x/n.md' 'old'; Base
Put 'delivery/results/acceptance-x/n.md' 'new'; Run "24 parity: watch glob '*' does not cross '/' (ignored nested file)" pass
Setup; Add-Content .gitignore 'evidence/'; git commit -qam ign; $script:Cfg.Gates += 'evidence/**/*.md'; $script:Watch = $W + 'evidence/**/*.md'
Put 'evidence/x/y.md' 'old'; Base; Put 'evidence/x/y.md' 'new'; Run "25 parity: a whole '**' component spans folders (ignored nested gate file)" fail
Setup; Add-Content .gitignore 'logs/'; git commit -qam ign; $script:Cfg.Gates += 'logs/**/gate/*.md'; $script:Watch = $W + 'logs/**/gate/*.md'
Put 'logs/a/gate/sub/x.md' 'old'; Base; Put 'logs/a/gate/sub/x.md' 'new'; Run "26 parity: '*' after '**' still stays in one folder" pass
Setup; Base; Put 'delivery/results/acceptance-x/n.md' 'r'; Run "27 tracked: a file one folder below a gate glob is not a receipt" pass

''
"path-check ($($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)): $($script:Ok)/$($script:Ok + $script:Bad) fixtures as expected"
Set-Location $Work
exit ([int]($script:Bad -gt 0))
