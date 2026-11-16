#!/usr/bin/env python3
"""Extract the path-check and digest recipes from the plugin reference into runnable libraries.

The tests run the code exactly as published in
plugins/ai-team-sdlc/skills/ait-contract-mode/references/path-check-and-digests.md,
so the reference and the tests cannot drift apart.
Usage: python tests/recipes/extract_recipes.py <out-dir>   -> <out-dir>/lib.sh, <out-dir>/lib.ps1
"""
import os
import re
import sys

ROOT = os.path.abspath(os.environ.get("AIT_REPO_ROOT") or os.path.join(os.path.dirname(__file__), "..", ".."))  # AIT_REPO_ROOT: check another checkout
REF = os.path.join(ROOT, "plugins", "ai-team-sdlc", "skills", "ait-contract-mode", "references", "path-check-and-digests.md")
WANT = {
    "bash": ["folder_digest()", "path_check()", "path_check_classify()"],
    "powershell": ["function Get-FolderDigest", "function Invoke-PathCheck", "function Test-PathCheck"],
}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tests", "out", "recipes")
    os.makedirs(out, exist_ok=True)
    text = open(REF, encoding="utf-8").read().replace("\r\n", "\n")
    blocks = re.findall(r"```(bash|powershell)\n(.*?)```", text, re.S)
    for lang, names in WANT.items():
        code = []
        for name in names:
            found = [b for l, b in blocks if l == lang and name in b]
            if len(found) != 1:
                sys.exit(f"expected exactly one {lang} block defining {name}, found {len(found)}")
            # drop the example call lines that follow the function definitions
            body = "\n".join(l for l in found[0].splitlines() if not re.match(r"^(folder_digest|Get-FolderDigest) ", l))
            code.append(body)
        target = os.path.join(out, "lib.sh" if lang == "bash" else "lib.ps1")
        with open(target, "w", encoding="utf-8-sig" if lang == "powershell" else "utf-8", newline="\n") as f:
            f.write("\n\n".join(code) + "\n")
        print(target)


if __name__ == "__main__":
    main()
