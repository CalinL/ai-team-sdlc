#!/usr/bin/env python3
"""Tier 2 — digest parity: the bash and PowerShell digest recipes give the same result as an independent
Python implementation of ait-contract-mode §13 (file digest; canonical folder manifest, receipts excluded).
Usage: python tests/recipes/digest_parity.py <lib-dir> <work-dir>   (lib-dir holds lib.sh and lib.ps1)
"""
import hashlib
import os
import shutil
import subprocess
import sys

from shells import bash_path, powershell_paths, shell_env


def py_folder_digest(root, exclude):
    rows = []
    for dp, _, files in os.walk(root):
        for f in files:
            full = os.path.join(dp, f)
            relp = os.path.relpath(full, root).replace(os.sep, "/")
            if relp in exclude:
                continue
            rows.append((relp.encode("utf-8"), f"{relp} {hashlib.sha256(open(full, 'rb').read()).hexdigest()}"))
    rows.sort(key=lambda r: r[0])
    return hashlib.sha256("".join(r[1] + "\n" for r in rows).encode("utf-8")).hexdigest()


def make_fixture(root):
    files = {
        "index.html": "<h1>hi</h1>\n", "sub/B.css": "b{}\n", "a b.js": "x\n", ".hidden/z.txt": "z", "Z.md": "Z",
        "report.html": "", "report.html backup": "", "a-b": "", "a_b": "", "ACCEPTED.md": "receipt\n",
    }
    for name, body in files.items():
        p = os.path.join(root, *name.split("/"))
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(body)


def main():
    lib, work = sys.argv[1], sys.argv[2]
    fixture = os.path.join(work, "digest-fixture")
    shutil.rmtree(fixture, ignore_errors=True)
    make_fixture(fixture)
    expected = py_folder_digest(fixture, {"ACCEPTED.md"})
    file_expected = hashlib.sha256(open(os.path.join(fixture, "index.html"), "rb").read()).hexdigest()
    results, bad = [], 0
    bash = bash_path()
    if bash:
        out = subprocess.run([bash, "-c", f'source "{lib}/lib.sh"; cd "{work}"; folder_digest digest-fixture "ACCEPTED.md"; '
                              f'sha256sum -- digest-fixture/index.html | cut -d" " -f1'],
                             capture_output=True, text=True).stdout.split()
        results.append(("bash", out))
    for ps in powershell_paths():
        cmd = (f". '{lib}/lib.ps1'; Set-Location '{work}'; Get-FolderDigest -Dir digest-fixture -Exclude 'ACCEPTED.md'; "
               f"(Get-FileHash -Algorithm SHA256 -LiteralPath digest-fixture/index.html).Hash.ToLower()")
        out = subprocess.run([ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", cmd],         capture_output=True, text=True, env=shell_env(ps)).stdout.split()
        results.append((os.path.basename(ps), out))
    print(f"python reference: folder={expected[:16]}… file={file_expected[:16]}…")
    for name, out in results:
        ok = out == [expected, file_expected]
        bad += not ok
        print(f"{'OK ' if ok else 'BAD'}  {name:<16} folder={out[0][:16] if out else '?'}… file={out[1][:16] if len(out) > 1 else '?'}…")
    if not results:
        print("BAD  no shell found to test")
        bad += 1
    print(f"\ndigest parity: {len(results) - bad if results else 0}/{len(results)} shells match the reference")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
