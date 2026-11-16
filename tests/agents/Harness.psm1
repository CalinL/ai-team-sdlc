# Tier 3 — agent-probe harness. Runs the plugin from this working tree (copilot --plugin-dir) against
# small scratch repos and grades the files, git state and transcript each run leaves behind.
# Scratch repos live under $env:TEMP (outside this repo, so its AGENTS.md never leaks into a probe);
# transcripts go to tests/out/agents/<stamp>/.
$ErrorActionPreference = 'Stop'
$script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script:PluginDir = if ($env:AIT_PLUGIN_DIR) { (Resolve-Path $env:AIT_PLUGIN_DIR).Path } else { Join-Path $script:RepoRoot 'plugins/ai-team-sdlc' }   # AIT_PLUGIN_DIR: test another worktree's plugin
$script:InstalledId = 'ai-team-sdlc@ai-team-sdlc'

function Get-RepoRoot { $script:RepoRoot }
function Get-PluginDir { $script:PluginDir }

# The installed copy of the plugin would shadow the one under test, so it is disabled for the session
# and re-enabled afterwards. A named mutex stops two sessions toggling it at once, and a marker file
# records that the tests disabled it, so a session that was killed mid-run is repaired by the next one.
function Use-PluginUnderTest([scriptblock]$Body) {
  $mutex = [Threading.Mutex]::new($false, 'Global\ait-team-sdlc-plugin-swap')
  $marker = Join-Path ([IO.Path]::GetTempPath()) 'ait-team-sdlc-plugin-disabled-by-tests.flag'
  $acquired = $false; $restore = $false
  try {
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(1)) } catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Another test session is using the plugin; try again when it finishes.' }
    $restore = Test-Path -LiteralPath $marker   # a killed session disabled it and never restored it
    $initial = Get-InstalledPluginState
    if ($initial -eq 'unknown') { throw 'Could not read the installed plugins (copilot plugin list failed); not running, so the installed copy cannot shadow the plugin under test.' }
    if ($initial -eq 'enabled') {
      Set-Content -LiteralPath $marker -Value $script:InstalledId; $restore = $true
      $out = copilot plugin disable $script:InstalledId 2>&1 | Out-String
      if ($LASTEXITCODE -or (Get-InstalledPluginState) -ne 'disabled') { throw "Could not disable the installed $($script:InstalledId), so it would shadow the plugin under test: $out" }
    }
    & $Body
  } finally {
    try {
      if ($restore) {
        $state = Get-InstalledPluginState
        if ($state -ne 'absent') {
          $out = copilot plugin enable $script:InstalledId 2>&1 | Out-String
          if ($LASTEXITCODE -or (Get-InstalledPluginState) -ne 'enabled') {   # the marker stays, so the next session retries
            throw "Could not confirm your installed $($script:InstalledId) is enabled again. Run: copilot plugin enable $($script:InstalledId)`n$out"
          }
        }
        Remove-Item -LiteralPath $marker -ErrorAction SilentlyContinue
      }
    } finally { if ($acquired) { $mutex.ReleaseMutex() }; $mutex.Dispose() }
  }
}

# 'enabled', 'disabled' or 'absent' for the installed copy of this plugin.
function Get-InstalledPluginState {
  $out = copilot plugin list 2>&1 | Out-String
  if ($LASTEXITCODE) { return 'unknown' }   # a failed lookup is never taken for "not installed"
  $line = $out -split "`r?`n" | Where-Object { $_ -match "\s$([regex]::Escape($script:InstalledId))\s" } | Select-Object -First 1
  if (-not $line) { 'absent' } elseif ($line -match '\[disabled\]') { 'disabled' } else { 'enabled' }
}

# A unique id for one test session's output and scratch folders (two sessions may start in the same second).
function New-RunStamp { '{0}-{1}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), [guid]::NewGuid().ToString('N').Substring(0, 6) }

function Write-RepoFile([string]$Root, [string]$Rel, [string]$Text) {
  $p = Join-Path $Root $Rel
  $d = Split-Path $p
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
  [IO.File]::WriteAllText($p, $Text.Replace("`r`n", "`n"), [Text.UTF8Encoding]::new($false))
}

function New-ScratchRepo([string]$Path, [hashtable]$Files = @{}, [string]$Message = 'seed') {
  if (Test-Path $Path) { throw "Scratch path already exists, refusing to reuse it: $Path" }
  New-Item -ItemType Directory -Force -Path $Path | Out-Null
  Push-Location $Path
  try {
    git init -q -b main 2>$null; if ($LASTEXITCODE) { git init -q }
    git config user.name 'AIT Test'; git config user.email 'ait-test@example.com'; git config core.autocrlf false
    if (-not $Files.ContainsKey('README.md')) { $Files['README.md'] = "# Scratch repo`n" }
    foreach ($k in $Files.Keys) { Write-RepoFile $Path $k $Files[$k] }
    git add -A; git commit -qm $Message
  } finally { Pop-Location }
}

function Remove-Scratch([string]$Path) {
  if (-not (Test-Path $Path)) { return }
  Get-ChildItem $Path -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { $_.Attributes = 'Normal' }
  Remove-Item -Recurse -Force $Path
}

# Every file on disk (tracked, untracked or ignored), repo-relative with '/', excluding .git/.
function Get-AllFiles([string]$Root) {
  $r = (Resolve-Path $Root).Path
  @(Get-ChildItem -LiteralPath $r -Recurse -File -Force -ErrorAction SilentlyContinue |
    ForEach-Object { $_.FullName.Substring($r.Length + 1).Replace('\', '/') } |
    Where-Object { $_ -notmatch '^\.git/' } | Sort-Object)
}

function Get-FileHashes([string]$Root) {
  $h = @{}
  foreach ($f in Get-AllFiles $Root) { $h[$f] = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $Root $f)).Hash }
  $h
}

# Files added, modified or deleted since a Get-FileHashes snapshot.
function Get-ChangedFiles([string]$Root, [hashtable]$Before) {
  $after = Get-FileHashes $Root
  @(@($after.Keys) + @($Before.Keys) | Sort-Object -Unique | Where-Object { $after[$_] -ne $Before[$_] })
}

function Invoke-Copilot {
  param([string]$Dir, [string]$Prompt, [string]$Model, [string]$Agent = '', [string]$Log, [double]$MaxCredits = 0)
  $a = @('--plugin-dir', $script:PluginDir, '--model', $Model, '--allow-all-tools', '--no-ask-user', '-p', $Prompt)
  if ($Agent) { $a = @('--agent', $Agent) + $a }
  if ($MaxCredits -gt 0) { $a += @('--max-ai-credits', "$MaxCredits") }
  Push-Location $Dir
  try {
    copilot @a 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -notmatch 'unknown fields? ignored' } |
      Out-File -FilePath $Log -Encoding utf8
  } finally { Pop-Location }
  $credits = 0.0
  $m = Select-String -LiteralPath $Log -Pattern 'AI Credits\s+([\d.]+)' | Select-Object -Last 1
  if ($m) { $credits = [double]$m.Matches[0].Groups[1].Value }
  [pscustomobject]@{ Log = $Log; Credits = $credits }
}

# Helpers for case checks: each returns $null when the condition holds, else a failure message.
function Expect([bool]$Cond, [string]$Message) { if (-not $Cond) { $Message } }
function Read-Text([string]$Root, [string]$Rel) { $p = Join-Path $Root $Rel; if (Test-Path -LiteralPath $p) { [IO.File]::ReadAllText($p) } else { '' } }
function Read-Json([string]$Root, [string]$Rel) { $t = Read-Text $Root $Rel; if ($t) { $t | ConvertFrom-Json } }
function Test-Committed([string]$Root, [string]$Rel) {
  Push-Location $Root; try { $null = git ls-files --error-unmatch -- $Rel 2>$null; ($LASTEXITCODE -eq 0) -and -not (git status --porcelain -- $Rel) } finally { Pop-Location }
}
# The assistant's own words: in the CLI transcript, tool calls and their output are indented and the
# reply starts at column 0, so a skill quoted by a tool can never satisfy a reply check.
function Get-ReplyText([string]$Log) {
  (($Log -split "`r?`n") | Where-Object { $_ -match '^\S' -and $_ -notmatch '^(Changes|AI Credits|Tokens|Resume)\s' }) -join "`n"
}
function Get-Transcript([string]$Log) { if (Test-Path -LiteralPath $Log) { [IO.File]::ReadAllText($Log) } else { '' } }

# Seeds .copilot-tracking/<RunId>/ (gitignored) with state.json, plan.md and inbox/. Pass Layout = $null
# for a run started on 1.1.0 (no layout block).
function New-RunState {
  param([string]$Root, [string]$RunId, [string]$Phase = 'deploy', [hashtable]$Signoff, $Layout = 'default', [object[]]$Tasks = @(), [hashtable]$Extra = @{})
  $dir = Join-Path $Root ".copilot-tracking/$RunId"
  New-Item -ItemType Directory -Force -Path (Join-Path $dir 'inbox/processed') | Out-Null
  $state = [ordered]@{ runId = $RunId; spec = './specs/prd.md'; mode = 'default'; status = 'in_progress'; currentPhase = $Phase
    updatedAt = '2026-01-01T12:00:00Z'; signoff = $Signoff; tasks = $Tasks }
  if ($Layout -eq 'default') {
    $state.layout = [ordered]@{ version = '1.1.1'; paths = [ordered]@{ prd = 'specs/prd.md'; features = 'specs/features/'; prototype = 'specs/ui/'
        decisions = 'architecture/adr/'; results = 'delivery/results/'; approvals = 'delivery/approvals.md'; release = 'delivery/release/' } }
  } elseif ($Layout) { $state.layout = $Layout }
  foreach ($k in $Extra.Keys) { $state[$k] = $Extra[$k] }
  Write-RepoFile $Root ".copilot-tracking/$RunId/state.json" ($state | ConvertTo-Json -Depth 10)
  $lines = @("# Plan — $RunId", '') + @($Tasks | ForEach-Object { "- [$(if ($_.status -eq 'done') { 'x' } else { ' ' })] $($_.id) $($_.title) ($($_.phase))" })
  Write-RepoFile $Root ".copilot-tracking/$RunId/plan.md" (($lines -join "`n") + "`n")
}

function Get-HeadSha([string]$Root) { Push-Location $Root; try { (git rev-parse HEAD).Trim() } finally { Pop-Location } }
function Invoke-Git([string]$Root, [string[]]$GitArgs) { Push-Location $Root; try { git @GitArgs 2>&1 | Out-Null } finally { Pop-Location } }

Export-ModuleMember -Function *
