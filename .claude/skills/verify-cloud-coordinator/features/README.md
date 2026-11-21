# Cloud-Coordinator verification map

The repository's user-facing surfaces today are its gate and its verification
tooling. Read this index before driving anything, then use the matching feature
file as the recipe. Every feature below is reachable in this checkout; none
needs auth, network, or seed data.

## Baseline preconditions

- Work from the repository root; launch with
  `bash .claude/skills/verify-cloud-coordinator/scripts/launch.sh`.
- `launch.sh` must print `launch: ready`. It establishes `/tmp/verify-cloud-coordinator/<run-id>/`
  and writes `run.env` there.
- `doctor.sh` must print `doctor: READY` before the first drive, after any failed
  drive, and after the checkout changes.
- Python ≥ 3.10 with PyYAML `6.0.3` must be importable (`requirements-dev.txt`).
- Evidence goes to `artifacts/verify/<run-id>/<feature>/` and is never removed.
- Never drive a run whose `run.env` revision no longer matches `HEAD`.

## Driving conventions

- Start every recipe from the baseline state: a launched, doctored run.
- Run every command exactly as written, from the repository root.
- `drive.sh` exits 0 only on the expected result; a nonzero exit is a failure
  with evidence written, never a skipped check.
- Inspect `artifacts/verify/<run-id>/<feature>/*.exit` for the recorded statuses.
- Run `cleanup.sh` after the pass, then confirm the evidence still exists.

## Proof and skip reporting

- `gate` proves the pass; `gate-negative` proves the pass can fail. Both are
  required before claiming the gate works.
- UI-level proof does not exist yet because there is no app; say so instead of
  inventing a screen to drive.
- Report an unreachable entry point with the attempted command and the unmet
  prerequisite. Do not report it as verified through another path.

## Features

- [Repository gate](./repository-gate.md) covers the checks that run on pull
  requests and pushes to the default branch, and their negative control.
- [Verification skill integrity](./verification-skill.md) covers the skill,
  feature map, and helper conventions that this map itself depends on.
