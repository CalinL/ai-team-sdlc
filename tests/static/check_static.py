#!/usr/bin/env python3
"""Tier 1 — static checks for the ai-team-sdlc plugin.

Fast, free and deterministic: run on every push (CI) and before every commit that touches the
plugin. Usage: python tests/static/check_static.py [--list]
Requires: Python 3.9+, PyYAML, git.
"""
import glob
import json
import os
import re
import subprocess
import sys

import yaml

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PLUGIN = os.path.join(ROOT, "plugins", "ai-team-sdlc")
VENDORED = ("frontend-design", "theme-factory", "web-artifacts-builder")
HEADER = "# Created by Calin Lupas with AI assistance. Credits: the repository's README.md (Authors and credits) and NOTICE."
ADAPTED = "# Adapted by Calin Lupas with AI assistance from Anthropic's webapp-testing (Apache-2.0). Credits: skills/NOTICE.md."
CONTRACT_HEADING = "### Contract mode (only when .github/ai-sdlc.yml defines contract)"
EXPECTED_CONTRACT_BLOCKS = 13  # release fact (1.1.0 spec §4.3); update deliberately when a release adds or removes blocks
MAX_SKILL_LINES = 500

CHECKS = []


def check(fn):
    CHECKS.append(fn)
    return fn


def rel(p):
    return os.path.relpath(p, ROOT).replace("\\", "/")


def read(p):
    with open(p, encoding="utf-8") as f:
        return f.read()


def front_matter(text):
    if not text.startswith("---"):
        return None
    parts = re.split(r"^---[ \t]*\r?$", text, maxsplit=2, flags=re.M)
    return yaml.safe_load(parts[1]) if len(parts) >= 3 else None


def agents():
    return sorted(glob.glob(os.path.join(PLUGIN, "agents", "*.agent.md")))


def prompts():
    return sorted(glob.glob(os.path.join(PLUGIN, "prompts", "*.prompt.md")))


def skills():
    return sorted(glob.glob(os.path.join(PLUGIN, "skills", "*", "SKILL.md")))


def strip_code(text):
    """Remove fenced code blocks (examples and templates are not live links or output paths)."""
    text = re.sub(r"(?ms)^[ \t]*```.*?^[ \t]*```", "", text)
    return re.sub(r"`[^`\n]*`", "", text)


# ---------------------------------------------------------------------------------------------
@check
def front_matter_parses():
    """Every agent, prompt and skill has YAML front matter with the keys its loader needs."""
    errors = []
    for f in agents() + prompts() + skills():
        try:
            fm = front_matter(read(f))
        except yaml.YAMLError as e:
            errors.append(f"{rel(f)}: invalid YAML ({e.__class__.__name__})")
            continue
        if not isinstance(fm, dict) or not fm.get("description"):
            errors.append(f"{rel(f)}: missing front matter or description")
            continue
        if f.endswith("SKILL.md") and fm.get("name") != os.path.basename(os.path.dirname(f)):
            errors.append(f"{rel(f)}: name '{fm.get('name')}' != folder name")
        if f.endswith(".agent.md") and fm.get("name") != os.path.basename(f)[: -len(".agent.md")]:
            errors.append(f"{rel(f)}: name '{fm.get('name')}' != file name")
    return errors


@check
def agent_frontmatter_policy():
    """Agents: no model pin (G2), include-custom-instructions (G1), and the 'Where your work goes' line."""
    errors = []
    for f in agents():
        text = read(f)
        fm = front_matter(text)
        if "model" in fm:
            errors.append(f"{rel(f)}: pins a model")
        if fm.get("include-custom-instructions") is not True:
            errors.append(f"{rel(f)}: include-custom-instructions is not true")
        if "**Where your work goes:**" not in text:
            errors.append(f"{rel(f)}: missing the 'Where your work goes' line")
    return errors


@check
def credit_headers():
    """Original files carry the credit header; ait-prototype-testing the 'Adapted' line; vendored skills none."""
    errors = []
    for f in agents() + prompts() + skills():
        lines = read(f).splitlines()
        second = lines[1] if len(lines) > 1 else ""
        folder = os.path.basename(os.path.dirname(f))
        if folder in VENDORED:
            if second.startswith("# Created by") or second.startswith("# Adapted by"):
                errors.append(f"{rel(f)}: vendored skill must not carry a credit header")
        elif folder == "ait-prototype-testing":
            if second != ADAPTED:
                errors.append(f"{rel(f)}: missing the 'Adapted' credit line")
        elif second != HEADER:
            errors.append(f"{rel(f)}: missing the credit header as the first front-matter line")
    return errors


@check
def vendored_skills_unchanged():
    """The three vendored skills match the pinned blob list (tests/static/vendored.lock)."""
    lock = os.path.join(os.path.dirname(__file__), "vendored.lock")
    expected = [l for l in read(lock).splitlines() if l and not l.startswith("#")]
    out = subprocess.run(["git", "-C", ROOT, "ls-files", "-s", "--"] + [f"plugins/ai-team-sdlc/skills/{v}" for v in VENDORED],
                         capture_output=True, text=True, check=True).stdout
    actual = [f"{l.split()[1]} {l.split(chr(9), 1)[1]}" for l in out.splitlines() if l]
    if actual != expected:
        missing = sorted(set(expected) - set(actual))
        extra = sorted(set(actual) - set(expected))
        return [f"pinned but changed or removed: {m}" for m in missing] + [f"not pinned: {x}" for x in extra]
    # a working-tree edit not yet staged also counts as a change
    dirty = subprocess.run(["git", "-C", ROOT, "status", "--porcelain", "--"] + [f"plugins/ai-team-sdlc/skills/{v}" for v in VENDORED],
                           capture_output=True, text=True, check=True).stdout.strip()
    return [f"uncommitted change: {l}" for l in dirty.splitlines()]


@check
def skill_size():
    """Skills stay under ~500 lines (long material goes to references/)."""
    return [f"{rel(f)}: {n} lines" for f in skills() if (n := len(read(f).splitlines())) > MAX_SKILL_LINES]


@check
def layout_table_matches_spec():
    """The ait-artifact-layout table equals the default-layout table of the latest change spec that defines one."""
    marker = "| Artifact | Default path | Written by |"

    def table(text):
        i = text.index(marker)
        rows = []
        for line in text[i:].splitlines():
            if not line.startswith("|"):
                break
            rows.append([c.strip() for c in line.strip().strip("|").split("|")])
        return rows

    specs = [p for p in sorted(glob.glob(os.path.join(ROOT, "docs", "changes", "*.md"))) if marker in read(p)]
    if not specs:
        return ["no change spec defines the default-layout table"]
    spec = specs[-1]
    skill = os.path.join(PLUGIN, "skills", "ait-artifact-layout", "SKILL.md")
    want = [[re.sub(r";\s*§[\d.]+\)", ")", c) for c in r] for r in table(read(spec))]
    got = table(read(skill))
    if want == got:
        return []
    diffs = [f"row {i}: spec={a} skill={b}" for i, (a, b) in enumerate(zip(want, got)) if a != b]
    if len(want) != len(got):
        diffs.append(f"row count: spec={len(want)} skill={len(got)}")
    return [f"{rel(spec)} vs {rel(skill)}"] + diffs


@check
def no_old_output_paths():
    """No 1.1.0 default output path (docs/…) outside the 1.1.0 table in ait-artifact-layout and the change specs."""
    pattern = re.compile(r"docs/(delivery|adr|requirements)|docs/<(product|company)>|`docs`|<code>docs</code>|\bin docs\b")
    files = glob.glob(os.path.join(PLUGIN, "**", "*.md"), recursive=True)
    files += glob.glob(os.path.join(ROOT, "docs", "**", "*.md"), recursive=True)
    files += glob.glob(os.path.join(ROOT, "docs", "**", "*.html"), recursive=True)
    files += [os.path.join(ROOT, "README.md"), os.path.join(ROOT, "AGENTS.md")]
    errors = []
    for f in files:
        r = rel(f)
        if "ait-artifact-layout/" in r or r.startswith("docs/changes/"):
            continue
        for n, line in enumerate(read(f).splitlines(), 1):
            if pattern.search(line):
                errors.append(f"{r}:{n}: {line.strip()[:120]}")
    return errors


@check
def approval_record_is_committed():
    """O2: nothing says the sign-off record, gate confirmations or waivers live in decisions.md."""
    pattern = re.compile(
        r"(waiver|sign-?off record|confirmation)[^.\n]{0,60}(recorded in|in an append.only|holds?)[^.\n]{0,20}`?decisions\.md"
        r"|`?decisions\.md`?[^.\n]{0,20}holds the human",
        re.I)
    allowed = re.compile(r"carried over|carry|from (its|the run's) `?decisions\.md|before 1\.1\.1|1\.1\.0|historical", re.I)
    files = glob.glob(os.path.join(PLUGIN, "**", "*.md"), recursive=True)
    files += [os.path.join(ROOT, "AGENTS.md"), os.path.join(ROOT, "docs", "ai-sdlc-usage.md")]
    errors = []
    for f in files:
        for n, line in enumerate(read(f).splitlines(), 1):
            if pattern.search(line) and not allowed.search(line):
                errors.append(f"{rel(f)}:{n}: {line.strip()[:120]}")
    return errors


@check
def approvals_file_is_human_only():
    """delivery/approvals.md is defined as human-sourced only (guard for the 1.1.1 end-to-end finding)."""
    needles = {
        "plugins/ai-team-sdlc/skills/ait-artifact-layout/SKILL.md": "Every entry comes from a real human turn",
        "plugins/ai-team-sdlc/agents/ait-scribe.agent.md": "Never record agent gate results there",
    }
    return [f"{p}: missing '{s}'" for p, s in needles.items() if s not in read(os.path.join(ROOT, p))]


@check
def contract_blocks_well_formed():
    """Each contract-mode block states its condition, points to ait-contract-mode, closes properly and is
    followed directly by a heading (no default text under a contract heading)."""
    errors = []
    count = 0
    for f in glob.glob(os.path.join(PLUGIN, "**", "*.md"), recursive=True):
        lines = read(f).splitlines()
        for i, line in enumerate(lines):
            if line != CONTRACT_HEADING:
                continue
            count += 1
            where = f"{rel(f)}:{i + 1}"
            try:
                j = lines.index("Otherwise ignore this section.", i)
            except ValueError:
                errors.append(f"{where}: no closing line")
                continue
            body = " ".join(lines[i + 1:j])
            if not lines[i + 1].startswith("Applies only when"):
                errors.append(f"{where}: first line does not state the condition")
            if "ait-contract-mode" not in body:
                errors.append(f"{where}: no pointer to ait-contract-mode")
            k = j + 1
            while k < len(lines) and not lines[k].strip():
                k += 1
            if k < len(lines) and not lines[k].startswith("#"):
                errors.append(f"{where}: default text follows the block ('{lines[k][:60]}')")
    if count != EXPECTED_CONTRACT_BLOCKS:
        errors.append(f"found {count} contract-mode blocks, expected {EXPECTED_CONTRACT_BLOCKS}")
    return errors


@check
def relative_links_resolve():
    """Relative links (outside code) in the docs, README, AGENTS, tests and the plugin resolve, anchors included.
    Change specs under docs/changes/ are skipped: they quote other files' text verbatim."""
    def slug(h):
        h = h.strip().lower()
        h = re.sub(r"[^\w\- ]", "", h)
        return h.replace(" ", "-")

    files = [os.path.join(ROOT, "README.md"), os.path.join(ROOT, "AGENTS.md")]
    for pattern in ("docs/**/*.md", "plugins/ai-team-sdlc/**/*.md", "tests/**/*.md"):
        files += glob.glob(os.path.join(ROOT, pattern), recursive=True)
    errors = []
    for doc in files:
        if rel(doc).startswith("docs/changes/"):
            continue
        text = strip_code(read(doc))
        for target in re.findall(r"\]\(([^)\s]+)\)", text):
            if re.match(r"^[a-z]+:", target):
                continue
            path, _, anchor = target.partition("#")
            full = os.path.normpath(os.path.join(os.path.dirname(doc), path)) if path else doc
            if not os.path.exists(full):
                errors.append(f"{rel(doc)} -> {target}")
            elif anchor and full.endswith(".md"):
                if anchor not in [slug(h) for h in re.findall(r"^#+ (.*)$", read(full), re.M)]:
                    errors.append(f"{rel(doc)} -> {target} (anchor)")
    return errors


@check
def versions_and_counts():
    """plugin.json and both marketplace versions agree; README and design-doc skill counts match the skills on disk."""
    errors = []
    p = json.loads(read(os.path.join(PLUGIN, "plugin.json")))
    m = json.loads(read(os.path.join(ROOT, ".github", "plugin", "marketplace.json")))
    versions = {p["version"], m["metadata"]["version"], m["plugins"][0]["version"]}
    if len(versions) != 1:
        errors.append(f"versions differ: {sorted(versions)}")
    names = [os.path.basename(os.path.dirname(f)) for f in skills()]
    core, vendored = sum(n.startswith("ait-") for n in names), sum(not n.startswith("ait-") for n in names)
    readme = re.search(r"\| (\d+) skills", read(os.path.join(ROOT, "README.md")))
    if not readme or int(readme.group(1)) != len(names):
        errors.append(f"README skill count {readme and readme.group(1)} != {len(names)} on disk")
    roster = re.search(r"(\d+) skills \((\d+) namespaced core \+ (\d+) unprefixed vendored\)",
                       read(os.path.join(ROOT, "docs", "ai-sdlc-design.md")))
    if not roster or tuple(map(int, roster.groups())) != (len(names), core, vendored):
        errors.append(f"design roster {roster and roster.groups()} != ({len(names)}, {core}, {vendored})")
    return errors


@check
def json_files_valid():
    """Manifests and the state.json template parse; the template carries the run keys."""
    errors = []
    for f in [os.path.join(PLUGIN, "plugin.json"), os.path.join(ROOT, ".github", "plugin", "marketplace.json")]:
        try:
            json.loads(read(f))
        except ValueError as e:
            errors.append(f"{rel(f)}: {e}")
    tpl = os.path.join(PLUGIN, "skills", "ait-sdlc-orchestrate", "references", "tracking-templates", "state.json")
    try:
        d = json.loads(read(tpl))
        errors += [f"{rel(tpl)}: missing '{k}'" for k in ("runId", "mode", "layout", "signoff", "tasks") if k not in d]
    except ValueError as e:
        errors.append(f"{rel(tpl)}: {e}")
    return errors


def main():
    if "--list" in sys.argv:
        for fn in CHECKS:
            print(f"{fn.__name__}: {fn.__doc__.strip().splitlines()[0]}")
        return 0
    failed = 0
    for fn in CHECKS:
        try:
            errors = fn()
        except Exception as e:  # a crashing check is a failing check
            errors = [f"check crashed: {e!r}"]
        print(f"{'PASS' if not errors else 'FAIL'}  {fn.__name__}")
        for e in errors[:25]:
            print(f"      {e}")
        if len(errors) > 25:
            print(f"      ... {len(errors) - 25} more")
        failed += bool(errors)
    print(f"\nstatic: {len(CHECKS) - failed}/{len(CHECKS)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
