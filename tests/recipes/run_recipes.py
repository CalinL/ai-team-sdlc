#!/usr/bin/env python3
"""Tier 2 — recipe tests: path-check fixtures in bash and every available PowerShell, plus digest parity.
All of them run the code extracted from the plugin reference. Free, deterministic, ~1–2 minutes.
Usage: python tests/recipes/run_recipes.py [out-dir]
"""
import os
import subprocess
import time
import sys

sys.path.insert(0, os.path.dirname(__file__))
from shells import bash_path, powershell_paths, shell_env  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def fwd(p):
    return p.replace("\\", "/")


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tests", "out", "recipes", f"{time.strftime('%Y%m%d-%H%M%S')}-{os.getpid()}"))  # one folder per run: parallel runs never share fixtures
    lib = os.path.join(out, "lib")
    subprocess.run([sys.executable, os.path.join(HERE, "extract_recipes.py"), lib], check=True, stdout=subprocess.DEVNULL)
    suites = []
    bash = bash_path()
    if bash:
        suites.append(("path-check (bash)", [bash, fwd(os.path.join(HERE, "path_check_fixtures.sh")), fwd(os.path.join(lib, "lib.sh")), fwd(os.path.join(out, "bash"))]))
    else:
        suites.append(("path-check (bash)", None))
    if not powershell_paths():
        suites.append(("path-check (PowerShell)", None))
    for ps in powershell_paths():
        name = os.path.splitext(os.path.basename(ps))[0]
        suites.append((f"path-check ({name})", [ps, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", os.path.join(HERE, "path_check_fixtures.ps1"),
                                                 "-Lib", os.path.join(lib, "lib.ps1"), "-Work", os.path.join(out, name)]))
    suites.append(("digest parity", [sys.executable, os.path.join(HERE, "digest_parity.py"), fwd(lib), fwd(out)]))
    failed = 0
    for name, cmd in suites:
        print(f"\n=== {name}", flush=True)
        if cmd is None:
            print("FAIL: shell not found")
            failed += 1
            continue
        rc = subprocess.run(cmd, cwd=out, env=shell_env(cmd[0])).returncode
        print(f"--> {'PASS' if rc == 0 else 'FAIL'}")
        failed += rc != 0
    print(f"\nrecipes: {len(suites) - failed}/{len(suites)} suites passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
