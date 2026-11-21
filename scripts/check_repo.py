#!/usr/bin/env python3
"""Validate this repository's CI workflow and verification skill.

Runs in CI and locally. Read-only: it never writes to the checkout.

Checks:
  * .github/workflows/ci.yml parses, triggers on pull_request and push to a
    branch list, has runnable jobs with pinned actions, and calls the
    repository checks.
  * At least one .claude/skills/verify-*/ skill exists with frontmatter, the
    six required sections in order, a linked feature map, feature files with
    exactly the four required H2 sections, and executable helpers.
  * The skill and its feature map contain no placeholder markers.

Exit status: 0 when every check passes, 1 otherwise. Requires PyYAML.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - exercised only on a bare host
    print(
        "error: PyYAML is required: python3 -m pip install --user pyyaml==6.0.3",
        file=sys.stderr,
    )
    raise SystemExit(1)

ROOT = Path(__file__).resolve().parent.parent
ERRORS: list[str] = []

REQUIRED_SKILL_SECTIONS = ["Launch", "Doctor", "Drive", "Evidence", "Cleanup", "Helpers"]
FEATURE_SECTIONS = [
    "Sub-features",
    "How to get to it (user POV)",
    "Gotchas",
]
PLACEHOLDERS = ("TODO", "FIXME", "TBD", "<app>", "<feature>")
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")

ACTION_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+@(v\d+|[0-9a-f]{40})$")
SCRIPT_RE = re.compile(r"\b(?:bash|python3?)\s+((?:\./)?[A-Za-z0-9_./-]+\.(?:sh|py))\b")
H2_RE = re.compile(r"^##[ \t]+(.+?)[ \t]*$", re.MULTILINE)
FRONTMATTER_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
LINK_RE = re.compile(r"\]\(([^)\s]+\.md)\)")


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def error(message: str) -> None:
    ERRORS.append(message)


def headline(path: Path, text: str) -> list[str]:
    return [h.strip() for h in H2_RE.findall(text)]


def check_placeholders(path: Path, text: str) -> None:
    """Reject placeholder markers in prose.

    Inline code spans are exempt: the skill has to be able to name the markers
    it forbids, and quoting a token is not leaving one behind.
    """
    prose = INLINE_CODE_RE.sub("", text)
    for token in PLACEHOLDERS:
        if token in prose:
            error(f"{rel(path)}: remove placeholder marker {token!r}")


def load_yaml(path: Path):
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        error(f"{rel(path)}: invalid YAML: {exc}")
        return None


def check_workflow() -> None:
    path = ROOT / ".github" / "workflows" / "ci.yml"
    if not path.is_file():
        error("missing .github/workflows/ci.yml")
        return

    text = path.read_text(encoding="utf-8")
    data = load_yaml(path)
    if not isinstance(data, dict):
        error(f"{rel(path)}: expected a YAML mapping")
        return

    # PyYAML follows YAML 1.1, where the bare key `on` loads as boolean True.
    triggers = data.get("on")
    if triggers is None and True in data:
        triggers = data[True]
    if not isinstance(triggers, dict):
        error(f"{rel(path)}: `on` must map triggers, got {triggers!r}")
    else:
        if "pull_request" not in triggers:
            error(f"{rel(path)}: missing pull_request trigger")
        push = triggers.get("push")
        if not isinstance(push, dict):
            error(f"{rel(path)}: missing push trigger")
        elif not push.get("branches"):
            error(
                f"{rel(path)}: push trigger must filter to the default branch "
                "with a non-empty branches list"
            )

    jobs = data.get("jobs")
    if not isinstance(jobs, dict) or not jobs:
        error(f"{rel(path)}: missing jobs")
        return
    for job_id, job in jobs.items():
        if not isinstance(job, dict):
            error(f"{rel(path)}: job {job_id!r} must be a mapping")
            continue
        if not job.get("runs-on"):
            error(f"{rel(path)}: job {job_id!r} has no runs-on")
        steps = job.get("steps")
        if not isinstance(steps, list) or not steps:
            error(f"{rel(path)}: job {job_id!r} has no steps")
            continue
        for index, step in enumerate(steps):
            if not isinstance(step, dict):
                error(f"{rel(path)}: job {job_id!r} step {index} must be a mapping")
                continue
            uses = step.get("uses")
            if uses is not None and not ACTION_RE.match(str(uses)):
                error(
                    f"{rel(path)}: job {job_id!r} step {index} uses {uses!r}; "
                    "pin actions to a major version or full commit SHA"
                )
            for script in SCRIPT_RE.findall(str(step.get("run", ""))):
                target = (ROOT / script).resolve()
                if not target.is_file():
                    error(
                        f"{rel(path)}: job {job_id!r} step {index} runs missing "
                        f"script {script!r}"
                    )
                elif not os.access(target, os.X_OK):
                    error(
                        f"{rel(path)}: job {job_id!r} step {index} runs "
                        f"non-executable script {script!r}"
                    )

    for command in (
        "scripts/check_repo.py",
        "scripts/run_project_tests.sh",
        ".claude/skills/verify-cloud-coordinator/scripts/doctor.sh",
    ):
        if command not in text:
            error(f"{rel(path)}: does not run {command}")


def check_feature_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    sections = headline(path, text)
    if len(sections) != 4:
        error(
            f"{rel(path)}: expected exactly 4 H2 sections, found {len(sections)}: {sections}"
        )
    expected_prefix = "Driving it with "
    if len(sections) == 4:
        ok = (
            sections[0] == "Sub-features"
            and sections[1] == "How to get to it (user POV)"
            and sections[2].startswith(expected_prefix)
            and len(sections[2]) > len(expected_prefix)
            and sections[3] == "Gotchas"
        )
        if not ok:
            error(
                f"{rel(path)}: H2 sections must be 'Sub-features', "
                "'How to get to it (user POV)', 'Driving it with <harness>', "
                f"'Gotchas' in that order; found {sections}"
            )
    check_placeholders(path, text)


def check_skill(skill: Path) -> None:
    skill_md = skill / "SKILL.md"
    if not skill_md.is_file():
        error(f"{rel(skill)}: missing SKILL.md")
        return

    text = skill_md.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(text)
    if not match:
        error(f"{rel(skill_md)}: missing YAML frontmatter")
    else:
        frontmatter = yaml.safe_load(match.group(1)) or {}
        if not isinstance(frontmatter, dict):
            error(f"{rel(skill_md)}: frontmatter must be a mapping")
        else:
            name = frontmatter.get("name")
            description = frontmatter.get("description")
            if name != skill.name:
                error(
                    f"{rel(skill_md)}: frontmatter name {name!r} must match "
                    f"directory name {skill.name!r}"
                )
            if not isinstance(description, str) or not description.strip():
                error(f"{rel(skill_md)}: frontmatter needs a non-empty description")

    sections = headline(skill_md, text)
    positions: list[int] = []
    for required in REQUIRED_SKILL_SECTIONS:
        if required not in sections:
            error(f"{rel(skill_md)}: missing required H2 section {required!r}")
        else:
            positions.append(sections.index(required))
    if positions != sorted(positions):
        error(
            f"{rel(skill_md)}: required sections must appear in order "
            f"{REQUIRED_SKILL_SECTIONS}"
        )
    check_placeholders(skill_md, text)

    features = skill / "features"
    index = features / "README.md"
    if not index.is_file():
        error(f"{rel(features)}: missing feature map README.md")
        return
    index_text = index.read_text(encoding="utf-8")
    check_placeholders(index, index_text)

    links = [link for link in LINK_RE.findall(index_text) if not link.startswith(("http://", "https://"))]
    if not links:
        error(f"{rel(index)}: links no feature files")
    linked: set[Path] = set()
    for link in links:
        target = (features / link).resolve()
        if not target.is_file():
            error(f"{rel(index)}: link target {link!r} does not exist")
        else:
            linked.add(target)

    feature_files = sorted(p for p in features.glob("*.md") if p.name != "README.md")
    if not feature_files:
        error(f"{rel(features)}: contains no feature files")
    for feature_file in feature_files:
        if feature_file.resolve() not in linked:
            error(f"{rel(feature_file)}: not linked from {rel(index)}")
        check_feature_file(feature_file)

    helpers = skill / "scripts"
    if not helpers.is_dir():
        error(f"{rel(skill)}: missing scripts/ helper directory")
    else:
        helper_files = [p for p in sorted(helpers.iterdir()) if p.is_file()]
        if not helper_files:
            error(f"{rel(helpers)}: ships no helper scripts")
        for helper in helper_files:
            if not os.access(helper, os.X_OK):
                error(f"{rel(helper)}: helper script is not executable")


def main() -> int:
    print(f"repo root: {ROOT}")
    check_workflow()
    print("check: CI workflow")

    skills_root = ROOT / ".claude" / "skills"
    skills = sorted(p for p in skills_root.glob("verify-*") if p.is_dir()) if skills_root.is_dir() else []
    if not skills:
        error("missing verification skill at .claude/skills/verify-*/")
    for skill in skills:
        check_skill(skill)
        print(f"check: skill {skill.name}")

    if ERRORS:
        print(f"FAIL: {len(ERRORS)} problem(s)", file=sys.stderr)
        for message in ERRORS:
            print(f"  - {message}", file=sys.stderr)
        return 1
    print("OK: repository checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
