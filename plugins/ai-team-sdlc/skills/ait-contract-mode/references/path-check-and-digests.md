# Contract mode — digests and `path-check` commands

Recipes for `ait-contract-mode` §13 (artifact identity) and §10 (`path-check`). The rules are in
`SKILL.md`; these commands implement them. Run from the repo root. Bash needs `git`, `sha256sum`,
`find`, `sort` (Git Bash on Windows has them); the PowerShell versions need PowerShell 7+ or 5.1.

> Digests are over the **working-tree bytes**. Line-ending conversion (`core.autocrlf`,
> `.gitattributes` `eol`) changes those bytes, so compute and verify a receipt's digest on
> checkouts with the same line-ending settings.

## File digest (§13)
```bash
sha256sum -- specs/features/001-orders/001-orders.md | cut -d' ' -f1
```
```powershell
(Get-FileHash -Algorithm SHA256 -LiteralPath specs/features/001-orders/001-orders.md).Hash.ToLower()
```

## Folder digest (§13)
Manifest: one line per file, `<path relative to the folder, '/' separators> <file SHA-256>`, sorted
by path in byte order, UTF-8, LF, trailing newline; the digest is the SHA-256 of the manifest.
Exclude every file matching an `external_gates[].file` (the receipts), given **relative to the
folder**, with `{spec}` / `{version}` replaced by `*`.

```bash
# usage: folder-digest <dir> [receipt-path-relative-to-dir ...]
folder_digest() {
  local dir=${1%/}; shift
  ( cd "$dir" && find . -type f -print0 | LC_ALL=C sort -z |
    while IFS= read -r -d '' p; do
      p=${p#./}
      for x in "$@"; do [[ "$p" == $x ]] && continue 2; done
      printf '%s %s\n' "$p" "$(sha256sum -- "$p" | cut -d' ' -f1)"
    done ) | sha256sum | cut -d' ' -f1
}
folder_digest specs/ui 'ACCEPTED.md'
```

```powershell
# usage: Get-FolderDigest -Dir <dir> [-Exclude <receipt paths relative to dir, wildcards allowed>]
function Get-FolderDigest([Parameter(Mandatory)][string]$Dir, [string[]]$Exclude = @()) {
  $root = (Resolve-Path -LiteralPath $Dir).Path.TrimEnd('\', '/')
  $utf8 = [Text.UTF8Encoding]::new($false)
  $keys = [System.Collections.Generic.List[string]]::new()
  $rows = [System.Collections.Generic.List[string]]::new()
  foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
    $rel = $f.FullName.Substring($root.Length + 1).Replace('\', '/')
    if ($Exclude | Where-Object { $rel -like $_ }) { continue }
    # sort key = the path's UTF-8 bytes as fixed-width hex, so ordinal order = byte order of the path
    $keys.Add((-join ($utf8.GetBytes($rel) | ForEach-Object { $_.ToString('x2') })))
    $rows.Add("$rel $((Get-FileHash -Algorithm SHA256 -LiteralPath $f.FullName).Hash.ToLower())")
  }
  $k = $keys.ToArray(); $r = $rows.ToArray(); [Array]::Sort($k, $r, [StringComparer]::Ordinal)
  $manifest = if ($r.Count) { ($r -join "`n") + "`n" } else { '' }
  -join ([Security.Cryptography.SHA256]::Create().ComputeHash($utf8.GetBytes($manifest)) | ForEach-Object { $_.ToString('x2') })
}
Get-FolderDigest -Dir specs/ui -Exclude 'ACCEPTED.md'
```
Both versions sort by the **path** (not by the whole manifest line) and produce the same digest for
the same bytes.

## Release candidate (§13)
```bash
git rev-parse HEAD          # record in state.json.signoff.artifact; {version} may use the short form
git rev-parse --short HEAD
```

## `path-check` (§10)
Keep `<dir>` inside the run's git-ignored tracking store, e.g.
`.copilot-tracking/<run-id>/baselines/<task-id>/`, so the baseline never shows up as a change and
survives a resume.

**Watched inputs.** Pass the same list to both calls: `contract.brief`, `contract.requirements`,
`.github/ai-sdlc.yml`, `delivery/approvals.md`, and every `external_gates[].file` with `{spec}` and
`{version}` replaced by `*`. They are hashed on disk, **whether Git tracks, ignores or doesn't know
them**, so a gitignored brief or a new receipt is still seen.

```bash
# path_check baseline <dir> [watch ...]   — before dispatch
# path_check changed  <dir> [watch ...]   — after the task: prints every path the task changed
path_check() {
  local cmd=$1 out=$2; shift 2
  _h() { if [ -e "$1" ]; then sha256sum -- "$1" | cut -d' ' -f1; else echo absent; fi; }
  _watch() {   # literal watch paths as given; globs expanded on disk (tracked, untracked or ignored)
    ( shopt -s nullglob globstar dotglob
      for w in "$@"; do
        case $w in *[*?[]*) for m in $w; do [ -f "$m" ] && printf '%s\n' "$m"; done ;;
                    *) printf '%s\n' "$w" ;; esac
      done ) | LC_ALL=C sort -u
  }
  if [ "$cmd" = baseline ]; then
    mkdir -p "$out"
    git rev-parse HEAD > "$out/head"
    git status --porcelain=v1 -uall -z > "$out/status"
    { git diff --no-renames --name-only -z HEAD; git ls-files --others --exclude-standard -z; } |
      LC_ALL=C sort -zu | while IFS= read -r -d '' p; do printf '%s\t%s\n' "$(_h "$p")" "$p"; done > "$out/hashes"
    _watch "$@" | while IFS= read -r p; do printf '%s\t%s\n' "$(_h "$p")" "$p"; done > "$out/watch"
    return 0
  fi
  local head; head=$(cat "$out/head")
  {
    { git diff --no-renames --name-only -z "$head"; git ls-files --others --exclude-standard -z;
      cut -f2- "$out/hashes" | tr '\n' '\0'; } | LC_ALL=C sort -zu |
    while IFS= read -r -d '' p; do
      local base; base=$(awk -F'\t' -v p="$p" '$2==p {print $1; exit}' "$out/hashes")
      if [ -n "$base" ]; then                  # dirty/untracked at baseline: compare to the recorded hash
        [ "$(_h "$p")" != "$base" ] && printf '%s\n' "$p"
      else                                     # otherwise compare to the blob at <baseline HEAD>
        local old new
        old=$(git rev-parse -q --verify "$head:$p" 2>/dev/null || echo absent)
        new=$( [ -e "$p" ] && git hash-object -- "$p" || echo absent)
        [ "$old" != "$new" ] && printf '%s\n' "$p"
      fi
    done
    # watched inputs whose hash changed, appeared or disappeared; new files matching a gate pattern
    { cut -f2- "$out/watch"; _watch "$@"; } | LC_ALL=C sort -u | while IFS= read -r p; do
      local was; was=$(awk -F'\t' -v p="$p" '$2==p {print $1; exit}' "$out/watch")
      [ "$(_h "$p")" != "${was:-absent}" ] && printf '%s\n' "$p"
    done
  } | LC_ALL=C sort -u
  return 0
}
```

```powershell
# Invoke-PathCheck -Mode baseline -Dir <dir> [-Watch <paths/globs>]   — before dispatch
# Invoke-PathCheck -Mode changed  -Dir <dir> [-Watch <paths/globs>]   — after the task
function Invoke-PathCheck([ValidateSet('baseline', 'changed')][string]$Mode, [string]$Dir, [string[]]$Watch = @()) {
  function HashOf($p) { if (Test-Path -LiteralPath $p -PathType Leaf) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower() } else { 'absent' } }
  function WatchList {   # literal watch paths as given; globs expanded on disk (tracked, untracked or ignored)
    $root = (Get-Location).Path
    $Watch | ForEach-Object {
      if ($_ -match '[*?\[]') { Get-ChildItem -Path $_ -File -Force -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') } }
      else { $_ }
    } | Sort-Object -Unique -CaseSensitive
  }
  function ReadMap($file) {
    $m = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    Get-Content -LiteralPath $file -Encoding utf8 | Where-Object { $_ } | ForEach-Object { $k = $_ -split "`t", 2; $m[$k[1]] = $k[0] }
    $m
  }
  $git = { git -c core.quotePath=false @args }
  if ($Mode -eq 'baseline') {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    & $git rev-parse HEAD | Set-Content -LiteralPath "$Dir/head" -Encoding utf8
    & $git status --porcelain=v1 -uall | Set-Content -LiteralPath "$Dir/status" -Encoding utf8
    @(& $git diff --no-renames --name-only HEAD) + @(& $git ls-files --others --exclude-standard) |
      Where-Object { $_ } | Sort-Object -Unique -CaseSensitive | ForEach-Object { "$(HashOf $_)`t$_" } |
      Set-Content -LiteralPath "$Dir/hashes" -Encoding utf8
    @(WatchList) | ForEach-Object { "$(HashOf $_)`t$_" } | Set-Content -LiteralPath "$Dir/watch" -Encoding utf8
    return
  }
  $head = (Get-Content -LiteralPath "$Dir/head" -Encoding utf8 | Select-Object -First 1).Trim()
  $base = ReadMap "$Dir/hashes"; $was = ReadMap "$Dir/watch"
  $cand = @(& $git diff --no-renames --name-only $head) + @(& $git ls-files --others --exclude-standard) + @($base.Keys)
  $changed = @(foreach ($p in ($cand | Where-Object { $_ } | Sort-Object -Unique -CaseSensitive)) {
    if ($base.ContainsKey($p)) { if ((HashOf $p) -ne $base[$p]) { $p } }   # dirty/untracked at baseline
    else {                                                              # otherwise the blob at <baseline HEAD>
      $old = & $git rev-parse -q --verify "${head}:$p" 2>$null; if (-not $old) { $old = 'absent' }
      $new = if (Test-Path -LiteralPath $p -PathType Leaf) { & $git hash-object -- $p } else { 'absent' }
      if ($old -ne $new) { $p }
    }
  })
  $changed += @(foreach ($p in (@($was.Keys) + @(WatchList) | Sort-Object -Unique -CaseSensitive)) {
    $w = if ($was.ContainsKey($p)) { $was[$p] } else { 'absent' }
    if ((HashOf $p) -ne $w) { $p }
  })
  $changed | Where-Object { $_ } | Sort-Object -Unique -CaseSensitive
}
```

Notes:
- `git diff <baseline HEAD>` compares the baseline commit with the working tree, so changes the task
  **committed** count too; `--no-renames` lists both names of a rename.
- `git hash-object` applies the same line-ending conversion as `git add`, so a CRLF checkout of an
  unchanged file is not reported.
- A pre-existing dirty or untracked file that the task left alone keeps its recorded hash and is
  not reported.

Then classify each reported path (paths in `ai-sdlc.yml` are prefixes relative to the repo root);
**the first match decides**:
1. under any `frozen` entry → **fail**;
2. `contract.brief`, `contract.requirements`, `.github/ai-sdlc.yml`, `delivery/approvals.md`, or a
   file matching an `external_gates[].file` pattern → **fail** (no exception, even inside
   `decisions.dir`);
3. a **new** file in `decisions.dir` (absent at baseline: not in `hashes` and not in
   `<baseline HEAD>`) whose status is `proposed_status` → **allowed**, even when `decisions.dir`
   itself sits under a `protected` entry;
4. any other path under a `protected` entry or in `decisions.dir` → **fail**;
5. anything else → **allowed**.

**Then, once per task, even when no path changed:** if `contract.path_check` is set, run it; a
non-zero exit → **fail**. `path-check` passes only when no path fails and that command (if any)
exits 0.

```bash
# path_check changed <dir> [watch ...] | path_check_classify <dir>
# Prints "<pass|FAIL> <rule> <path>" per path (and "<pass|FAIL> command"); returns 1 on failure.
# Set from .github/ai-sdlc.yml (lists are newline-separated):
#   PC_FROZEN, PC_PROTECTED  path prefixes           PC_DECISIONS_DIR, PC_PROPOSED  decisions.dir, proposed_status
#   PC_INPUTS   brief, requirements, .github/ai-sdlc.yml, delivery/approvals.md
#   PC_GATES    external_gates[].file with {spec}/{version} → *     PC_COMMAND  contract.path_check
path_check_classify() {
  local out=$1 head fail=0 p
  head=$(cat "$out/head")
  _under() { local x; while IFS= read -r x; do [ -n "$x" ] || continue
    case $1 in "${x%/}"|"${x%/}"/*) return 0 ;; esac; done <<< "$2"; return 1; }
  _input() { local x; while IFS= read -r x; do [ -n "$x" ] && [ "$1" = "$x" ] && return 0; done <<< "$PC_INPUTS"; return 1; }
  _gate()  { local g; while IFS= read -r g; do [ -n "$g" ] && [[ $1 == $g ]] && return 0; done <<< "$PC_GATES"; return 1; }
  _new()   { ! awk -F'\t' -v p="$1" '$2==p {f=1} END {exit !f}' "$out/hashes" && ! git cat-file -e "$head:$1" 2>/dev/null; }
  _proposed() { [ -f "$1" ] && grep -Eiq "^[[:space:]]*[-*]?[[:space:]]*(\*\*)?status(\*\*)?[[:space:]]*:[[:space:]]*(\*\*)?${PC_PROPOSED}(\*\*)?[[:space:]]*$" "$1"; }
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    if   _under "$p" "$PC_FROZEN";                 then echo "FAIL 1-frozen $p"; fail=1
    elif _input "$p" || _gate "$p";                then echo "FAIL 2-input-or-receipt $p"; fail=1
    elif [ -n "$PC_DECISIONS_DIR" ] && _under "$p" "$PC_DECISIONS_DIR" && _new "$p" && _proposed "$p"
                                                   then echo "pass 3-new-proposed-record $p"
    elif _under "$p" "$PC_PROTECTED" || { [ -n "$PC_DECISIONS_DIR" ] && _under "$p" "$PC_DECISIONS_DIR"; }
                                                   then echo "FAIL 4-protected-or-decisions $p"; fail=1
    else echo "pass 5-other $p"; fi
  done
  if [ -n "$PC_COMMAND" ]; then
    if sh -c "$PC_COMMAND"; then echo "pass command"; else echo "FAIL command"; fail=1; fi
  fi
  return $fail
}
```

```powershell
# Invoke-PathCheck -Mode changed ... | Test-PathCheck -Dir <dir> -Frozen ... -Protected ... `
#   -DecisionsDir <decisions.dir> -Proposed <proposed_status> -Inputs <brief, requirements, .github/ai-sdlc.yml, delivery/approvals.md> `
#   -Gates <external_gates[].file with {spec}/{version} → *> -Command <contract.path_check>
# Emits one object per path (and one for the command); $true in .Pass on every object = path-check passes.
function Test-PathCheck {
  param([Parameter(ValueFromPipeline)][string]$Path, [string]$Dir, [string[]]$Frozen = @(), [string[]]$Protected = @(),
        [string]$DecisionsDir = '', [string]$Proposed = 'Proposed', [string[]]$Inputs = @(), [string[]]$Gates = @(), [string]$Command = '')
  begin {
    $head = (Get-Content -LiteralPath "$Dir/head" -Encoding utf8 | Select-Object -First 1).Trim()
    $base = @(Get-Content -LiteralPath "$Dir/hashes" -Encoding utf8 | Where-Object { $_ } | ForEach-Object { ($_ -split "`t", 2)[1] })
    function Under($p, $list) { foreach ($x in $list) { if ($x) { $x = $x.TrimEnd('/')
      if ($p -ceq $x -or $p.StartsWith("$x/", [StringComparison]::Ordinal)) { return $true } } }; $false }
    function InHead($p) { git cat-file -e "${head}:$p" 2>$null; $LASTEXITCODE -eq 0 }
    $statusRx = '^\s*[-*]?\s*(\*\*)?status(\*\*)?\s*:\s*(\*\*)?' + [regex]::Escape($Proposed) + '(\*\*)?\s*$'
  }
  process {
    if (-not $Path) { return }
    $inDec = $DecisionsDir -and (Under $Path @($DecisionsDir))
    $r = if (Under $Path $Frozen) { 1, $false }
      elseif (($Inputs -ccontains $Path) -or @($Gates | Where-Object { $Path -clike $_ }).Count) { 2, $false }
      elseif ($inDec -and ($base -cnotcontains $Path) -and -not (InHead $Path) -and (Test-Path -LiteralPath $Path) -and
              (Select-String -LiteralPath $Path -Pattern $statusRx -Quiet)) { 3, $true }
      elseif ((Under $Path $Protected) -or $inDec) { 4, $false }
      else { 5, $true }
    [pscustomobject]@{ Pass = $r[1]; Rule = $r[0]; Path = $Path }
  }
  end {
    if ($Command) {
      $global:LASTEXITCODE = 0; $ok = $true
      try { Invoke-Expression $Command | Out-Host; $ok = $? -and $LASTEXITCODE -eq 0 } catch { $ok = $false }
      [pscustomobject]@{ Pass = $ok; Rule = 'command'; Path = $Command }
    }
  }
}
```
On Windows, a `.sh` value of `contract.path_check` needs Git Bash: pass `-Command "bash scripts/check-paths.sh"`.
