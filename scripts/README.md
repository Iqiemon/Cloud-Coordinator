# Cloud-Coordinator repository checks

Validate the CI workflow and the verification skill.

## Usage

```sh
python3 scripts/check_repo.py
```

Exit code `0` means every check passed; `1` means at least one problem, listed on
stderr. Requires PyYAML (`python3 -m pip install --user -r requirements-dev.txt`).

## What it checks

- `.github/workflows/ci.yml` exists, parses, and triggers on `pull_request` and
  on `push` to a non-empty branch list.
- Every job has `runs-on` and steps, and every `uses:` action is pinned to a
  major version tag (`@v4`) or a full commit SHA.
- The workflow runs this script, `scripts/run_project_tests.sh`, and the
  verification skill's doctor check.
- `.claude/skills/verify-*/` exists with valid frontmatter, the six required
  sections in order, a feature map README that links every feature file, feature
  files with exactly the four required H2 sections, and executable helpers.
- No placeholder markers (`TODO`, `TBD`, `<app>`, ...) remain in the skill or map.

The checker resolves the repository root from its own location, so it can be run
against a scratch copy. That is how the verification skill proves the gate
actually fails when the workflow or the skill is broken.

## Adding a check

Add the rule to this file and a corresponding negative control in
`.claude/skills/verify-cloud-coordinator/scripts/drive.sh` so a passing gate is
never just an untested pass.
