# Repository gate

The gate is the pass/fail signal a contributor sees on a pull request and on
every push to the default branch. It validates the CI workflow itself, runs the
project test suite, and drives this verification skill, so a broken workflow or
a broken skill turns the PR red instead of merging silently.

## Sub-features

- `gate-pr` runs on every pull request, whatever the base branch.
- `gate-push` runs on every push to the default branch, `spike/test`.
- `gate-workflow-check` rejects a workflow that loses either trigger, a non-empty
  branch filter, a job without steps, an action that is not version- or
  SHA-pinned, or a step that runs a missing or non-executable script.
- `gate-tests` runs `scripts/run_project_tests.sh`, which is a no-op that says so
  until the repository gains a test suite.
- `gate-negative` proves the checker fails on each broken input, so a green run
  is not an unconditional pass.

## How to get to it (user POV)

- Open a pull request against `spike/test`; the `CI` workflow appears in the
  checks list with the `Repository checks` and `Verification skill` jobs.
- Push to `spike/test`; the same workflow runs on the pushed commit.
- Locally, run `python3 scripts/check_repo.py` from the repository root.
- Locally, run `bash scripts/run_project_tests.sh` to run the test suite.

## Driving it with drive.sh

Preconditions:

- `launch.sh` printed `launch: ready` and `doctor.sh` printed `doctor: READY`.
- The working tree is clean of unrelated edits to `.github/`, `scripts/`, and
  `.claude/skills/verify-cloud-coordinator/`.

- **Positive gate.** Run `bash .claude/skills/verify-cloud-coordinator/scripts/drive.sh gate`.
  It exits `0`; `artifacts/verify/<run-id>/gate/gate.exit` contains `0` and
  `gate/gate.out` ends with `OK: repository checks passed`. `project-tests.exit`
  contains `0` and `project-tests.out` says `no test suite configured yet`.
- **Negative control.** Run `bash .claude/skills/verify-cloud-coordinator/scripts/drive.sh gate-negative`.
  It exits `0` only after recording failures for all five broken copies:
  `workflow-no-pull-request.exit`, `workflow-missing-script.exit`,
  `workflow-unpinned-action.exit`, `skill-missing-gotchas.exit`, and
  `skill-placeholder.exit`, each containing `1`, with `baseline.exit` containing
  `0`.
- **Specific reason.** Read `workflow-no-pull-request.out`; it names
  `missing pull_request trigger`. Read `workflow-missing-script.out`; it names
  `runs missing script 'scripts/missing.sh'`. Read
  `workflow-unpinned-action.out`; it names the unpinned `actions/checkout@main`
  step. A failure for any other reason means the gate regressed.
- **Workflow shape.** Run `python3 -c "import yaml,sys; print(yaml.safe_load(open('.github/workflows/ci.yml'))[True])"`
  and confirm `pull_request` is present and `push.branches` contains `spike/test`.
- **Evidence.** Confirm `artifacts/verify/<run-id>/gate-negative/` holds ten
  `.out`/`.exit` pairs; the five negative `.exit` files each read `1`.

## Gotchas

- PyYAML parses the workflow key `on` as boolean `True`; read it as `True` in
  Python or quote it in the YAML. The checker handles both.
- `gate-negative` works in a `mktemp -d` copy and removes it on exit; never edit
  the checkout to create a negative case.
- The push trigger lists `spike/test` because that is the default branch. When
  the default branch changes, update `branches` and the checker together, or
  `gate-push` stops covering the default branch.
- `run_project_tests.sh` exits 0 with no tests on purpose. A suite that exists but
  is not wired into it is a gate gap: add the command there, not in the workflow.
- Actions must be pinned to a major tag (`@v4`) or a full SHA. An unpinned ref
  such as `@main` is rejected by design.
