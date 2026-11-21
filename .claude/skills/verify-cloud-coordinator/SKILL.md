---
name: verify-cloud-coordinator
description: "Drive and prove Cloud-Coordinator's repository surfaces — the CI gate on pull requests and pushes to the default branch, the repository checker, and this verification skill's own integrity. Use before claiming a change to the workflow, the checker, or the verification map works, or when asked to verify this repo."
---

# Verify Cloud-Coordinator

Cloud-Coordinator is a repository with no application code yet: the root commit
has an empty tree and the default branch is `spike/test`. What a user touches
today is the repository's gate — GitHub Actions on every pull request and every
push to `spike/test`, the checker those jobs run, and this verification skill.
Each of those is a feature in `features/` with an exact proof.

Read `features/README.md` before driving anything. Drive one mapped feature at a
time and capture its evidence in `artifacts/verify/<run-id>/<feature>/`.

## Launch

There is no server or long-lived app. Launch prepares an isolated run
environment: a scratch directory under `/tmp/verify-cloud-coordinator/`, the one
Python dependency (`PyYAML==6.0.3`), and a baseline gate run that must pass
before the instance is worth driving.

```sh
bash .claude/skills/verify-cloud-coordinator/scripts/launch.sh
```

The script prints `launch: ready` followed by the run directory and records the
checkout revision, branch, and start time in `<run-dir>/run.env`. It exits 1 and
prints the baseline check log when the checkout's own gate fails; fix that
before driving. Ready means "baseline gate passed", not "the script ran".

Two runs can coexist: each gets its own run directory, and neither mutates the
checkout (the negative drives use a scratch copy). They cannot share a checkout
at different revisions, because the checks read the working tree. Launch
overwrites `.claude/skills/verify-cloud-coordinator/.last-run`, so drive the
run you just launched.

Teardown: `scripts/cleanup.sh` (see Cleanup).

## Doctor

Read-only check answering "is this instance worth driving?":

```sh
bash .claude/skills/verify-cloud-coordinator/scripts/doctor.sh
```

It verifies the launch environment exists, the checkout is the one the run
launched against, `HEAD` has not moved since launch, this run owns the checkout,
and Python ≥ 3.10 with PyYAML is available. It prints one line per check and
ends with `doctor: READY` or `doctor: NOT READY (n failure(s))`. Run it first
when anything looks off, after any failed drive, and after any checkout change.
A `revision` failure means relaunch; do not drive a stale run.

## Drive

The harness is the skill's own helpers, one feature per invocation:

```sh
bash .claude/skills/verify-cloud-coordinator/scripts/drive.sh gate
bash .claude/skills/verify-cloud-coordinator/scripts/drive.sh gate-negative
bash .claude/skills/verify-cloud-coordinator/scripts/drive.sh skill-map
```

- `gate` runs `scripts/check_repo.py` and `scripts/run_project_tests.sh` on this
  checkout and requires exit 0 from both.
- `gate-negative` copies the checkout, breaks the gate five ways (drops the
  `pull_request` trigger, points a step at a missing script, unpins an action,
  deletes a feature file's `Gotchas` section, appends a placeholder to the
  skill), and requires the checker to fail each time. This is the control that
  proves `gate` is not an unconditional pass.
- `skill-map` runs the checker and requires it to report the verification skill.

Each drive exits 0 only when the expected observable result was seen. Exact
per-feature commands and expected output are in `features/`. The harness never
edits the checkout; `gate-negative` works in a `mktemp -d` copy of it.

## Evidence

Every drive writes to `artifacts/verify/<run-id>/<feature>/`:

- `run.txt` — feature, checkout revision, start time.
- `<label>.out` — the checker's stdout and stderr for that check.
- `<label>.exit` — the process exit status.

`artifacts/` is git-ignored but never deleted by cleanup. Proof standards:

- Prove the user path, not an internal shortcut. `gate` runs the same command CI
  runs, from the same working tree.
- Capture the action and the resulting state. A passing run is only proof when
  `gate-negative` shows the same checker failing on a broken copy; both results
  live side by side in the evidence directory.
- Check side effects, not just output. `gate-negative` asserts on exit codes and
  the specific error line for each broken input, so a checker that fails for the
  wrong reason does not pass.
- Mocks: none. The checker reads real repository files; nothing external is
  stubbed.

A drive that fails writes the same evidence, so a failure is inspectable too.

## Cleanup

```sh
bash .claude/skills/verify-cloud-coordinator/scripts/cleanup.sh
```

Removes the run directory under `/tmp/verify-cloud-coordinator/` and the
`.last-run` pointer, and refuses to remove anything outside that prefix. It does
not touch `artifacts/verify/`: proof artifacts survive teardown, and the script
prints the kept directories. Nothing here starts a process, so there is nothing
to kill; the `gate-negative` scratch copy is removed by the drive's own trap.

Run cleanup after a successful pass and after every failed iteration, so a
broken attempt does not leave a run directory that later looks live.

## Helpers

All helpers live in `scripts/`, are executable, and are invoked as shown above.

| Helper | Purpose |
| --- | --- |
| `launch.sh` | Create the run directory, ensure PyYAML, run the baseline gate |
| `doctor.sh` | Read-only readiness check for the launched run |
| `drive.sh <feature>` | Exercise one mapped feature and capture evidence |
| `cleanup.sh` | Remove run scratch; keep evidence |

The evaluator the whole gate rests on is `scripts/check_repo.py` at the
repository root; `scripts/README.md` documents what it checks.
