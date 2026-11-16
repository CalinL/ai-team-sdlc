#!/usr/bin/env python3
"""Mutation self-test for tier 1: each mutation must make its target check fail, and the clean copy must pass.

Copies the working tree (without .git) to a temp repo, commits it, then for each mutation restores the
clean tree, applies one deliberate violation and runs the static checks in-process.
Usage: python tests/static/self_test.py
"""
import importlib.util
import os
import shutil
import stat
import subprocess
import sys
import tempfile

os.environ.pop("AIT_REPO_ROOT", None)   # the mutated copies must be checked, not another checkout

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.abspath(os.path.join(HERE, "..", ".."))
P = "plugins/ai-team-sdlc"


def replace(path, old, new):
    def apply(root):
        f = os.path.join(root, path)
        with open(f, encoding="utf-8") as fh:
            t = fh.read()
        assert old in t, f"mutation anchor not found in {path}: {old[:60]!r}"
        with open(f, "w", encoding="utf-8", newline="") as fh:
            fh.write(t.replace(old, new, 1))
    return apply


MUTATIONS = [
    ("front_matter_parses", replace(f"{P}/skills/ait-deploy/SKILL.md", "name: ait-deploy", "name: [ait-deploy")),
    ("agent_frontmatter_policy", replace(f"{P}/agents/ait-qa-test.agent.md", "include-custom-instructions: true", "include-custom-instructions: true\nmodel: gpt-5")),
    ("credit_headers", replace(f"{P}/prompts/product-qa.prompt.md", "# Created by Calin Lupas", "# Made by")),
    ("vendored_skills_unchanged", replace(f"{P}/skills/theme-factory/SKILL.md", "name: theme-factory", "name: theme-factory\n# local edit")),
    ("no_old_output_paths", replace(f"{P}/skills/ait-product-showcase/SKILL.md", "## Output files", "## Output files\nSee `docs/<product>-v1.html`.")),
    ("approval_record_is_committed", replace(f"{P}/skills/ait-quality-gates/SKILL.md", "Follow the `ait-conventions` skill.", "Follow the `ait-conventions` skill. A skipped gate needs a waiver recorded in `decisions.md`.")),
    ("approvals_file_is_human_only", replace(f"{P}/agents/ait-scribe.agent.md", "Never record agent gate results there", "Record agent gate results there too")),
    ("contract_blocks_well_formed", replace(f"{P}/skills/ait-sdlc-orchestrate/references/decompose.md", "Otherwise ignore this section.\n", "Otherwise ignore this section.\nDefault text that now sits under the contract heading.\n")),
    ("layout_table_matches_spec", replace(f"{P}/skills/ait-artifact-layout/SKILL.md", "| PRD | `specs/prd.md` |", "| PRD | `docs/prd.md` |")),
    ("relative_links_resolve", replace("README.md", "](NOTICE)", "](NOTICE-missing)")),
    ("versions_and_counts", replace(f"{P}/plugin.json", '"version": "', '"version": "9.')),
    ("json_files_valid", replace(f"{P}/skills/ait-sdlc-orchestrate/references/tracking-templates/state.json", '"layout"', '"lay_out"')),
    ("skill_size", replace(f"{P}/skills/ait-init/SKILL.md", "## Guardrails", "\n" * 500 + "## Guardrails")),
]


def load_checks(root):
    spec = importlib.util.spec_from_file_location("check_static_copy", os.path.join(root, "tests", "static", "check_static.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run_all(root):
    mod = load_checks(root)
    return {fn.__name__: bool(fn()) for fn in mod.CHECKS}  # True = failed


def rmtree(path):
    """shutil.rmtree that also removes read-only files (git objects on Windows)."""
    def onexc(func, p, _exc):
        os.chmod(p, stat.S_IWRITE)
        func(p)
    if sys.version_info >= (3, 12):
        shutil.rmtree(path, onexc=onexc)
    else:
        shutil.rmtree(path, onerror=onexc)


def git(root, *args):
    subprocess.run(["git", "-C", root, *args], check=True, capture_output=True)


def main():
    tmp = tempfile.mkdtemp(prefix="ait-static-selftest-")
    clean = os.path.join(tmp, "clean")
    work = os.path.join(tmp, "work")
    try:
        shutil.copytree(SRC, clean, ignore=shutil.ignore_patterns(".git", "out", "node_modules", ".copilot-tracking"))
        git(clean, "init", "-q")
        git(clean, "add", "-A")
        git(clean, "-c", "user.name=t", "-c", "user.email=t@e.x", "commit", "-q", "-m", "clean")
        failures = 0
        base = run_all(clean)
        bad = [k for k, v in base.items() if v]
        print(f"{'OK ' if not bad else 'BAD'}  clean copy passes every check{'' if not bad else ' — failing: ' + ', '.join(bad)}")
        failures += bool(bad)
        for target, mutate in MUTATIONS:
            if os.path.exists(work):
                rmtree(work)
            shutil.copytree(clean, work)
            mutate(work)
            result = run_all(work)
            failed = sorted(k for k, v in result.items() if v)
            ok = failed == [target]
            failures += not ok
            print(f"{'OK ' if ok else 'BAD'}  mutation for {target:<30} -> failing checks: {', '.join(failed) or 'none'}")
        print(f"\nself-test: {len(MUTATIONS) + 1 - failures}/{len(MUTATIONS) + 1} as expected")
        return 1 if failures else 0
    finally:
        rmtree(tmp)


if __name__ == "__main__":
    sys.exit(main())
