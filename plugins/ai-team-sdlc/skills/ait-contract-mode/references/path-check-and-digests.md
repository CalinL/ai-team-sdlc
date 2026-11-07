# Contract mode — digests and `path-check` commands

Recipes for `ait-contract-mode` §13 (artifact identity) and §10 (`path-check`). The rules are in
`SKILL.md`; these commands implement them. Run from the repo root. Bash needs `git`, `sha256sum`,
`find`, `sort` (Git Bash on Windows has them); the PowerShell versions need PowerShell 7+ or 5.1.

> Digests are over the **working-tree bytes**. Line-ending conversion (`core.autocrlf`,
> `.gitattributes` `eol`) changes those bytes, so compute and verify a receipt's digest on
> checkouts with the same line-ending settings.

## File digest (§13)
```bash
sha256sum -- docs/delivery/specs/orders.md | cut -d' ' -f1
```
```powershell
(Get-FileHash -Algorithm SHA256 -LiteralPath docs/delivery/specs/orders.md).Hash.ToLower()
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
folder_digest docs/delivery/prototype 'ACCEPTED.md'
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
Get-FolderDigest -Dir docs/delivery/prototype -Exclude 'ACCEPTED.md'
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

```bash
# path-check baseline <dir>   — before dispatch
# path-check changed  <dir>   — after the task: prints every path the task changed
path_check() {
  local cmd=$1 out=$2
  _h() { if [ -e "$1" ]; then sha256sum -- "$1" | cut -d' ' -f1; else echo absent; fi; }
  if [ "$cmd" = baseline ]; then
    mkdir -p "$out"
    git rev-parse HEAD > "$out/head"
    git status --porcelain=v1 -uall -z > "$out/status"
    { git diff --no-renames --name-only -z HEAD; git ls-files --others --exclude-standard -z; } |
      LC_ALL=C sort -zu | while IFS= read -r -d '' p; do printf '%s\t%s\n' "$(_h "$p")" "$p"; done > "$out/hashes"
    return 0
  fi
  local head; head=$(cat "$out/head")
  { git diff --no-renames --name-only -z "$head"; git ls-files --others --exclude-standard -z;
    cut -f2- "$out/hashes" | tr '\n' '\0'; } | LC_ALL=C sort -zu |
  while IFS= read -r -d '' p; do
    local base; base=$(awk -F'\t' -v p="$p" '$2==p {print $1; exit}' "$out/hashes")
    if [ -n "$base" ]; then                    # dirty/untracked at baseline: compare to the recorded hash
      [ "$(_h "$p")" != "$base" ] && printf '%s\n' "$p"
    else                                       # otherwise compare to the blob at <baseline HEAD>
      local old new
      old=$(git rev-parse -q --verify "$head:$p" 2>/dev/null || echo absent)
      new=$( [ -e "$p" ] && git hash-object -- "$p" || echo absent)
      [ "$old" != "$new" ] && printf '%s\n' "$p"
    fi
  done
  return 0
}
```

Notes:
- `git diff <baseline HEAD>` compares the baseline commit with the working tree, so changes the task
  **committed** count too; `--no-renames` lists both names of a rename.
- `git hash-object` applies the same line-ending conversion as `git add`, so a CRLF checkout of an
  unchanged file is not reported.
- A pre-existing dirty or untracked file that the task left alone keeps its recorded hash and is
  not reported.

Then classify each reported path (paths in `ai-sdlc.yml` are prefixes relative to the repo root),
in this order:
1. under any `frozen` entry → **fail** (no exception);
2. a **new** file in `decisions.dir` (absent at baseline: not in `hashes` and not in
   `<baseline HEAD>`) whose status is `proposed_status` → **allowed**, even when `decisions.dir`
   itself sits under a `protected` entry;
3. any other path under a `protected` entry or in `decisions.dir` → **fail**;
4. if `contract.path_check` is set, run it; a non-zero exit → **fail**.
`path-check` passes only when no path fails and the extra command (if any) exits 0.
