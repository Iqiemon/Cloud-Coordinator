# Verification skill integrity

The verification skill is how a future agent learns to drive this repository:
its frontmatter registers it, its six sections tell the agent how to launch,
check, drive, capture evidence, and clean up, and its feature map lists what
proving each surface means. If any of that rots, the next agent drives a
fictional app. CI checks this shape on every pull request.

## Sub-features

- `skill-frontmatter` requires `name: verify-cloud-coordinator` matching the
  directory and a non-empty `description`.
- `skill-sections` requires `Launch`, `Doctor`, `Drive`, `Evidence`, `Cleanup`,
  and `Helpers` as H2 sections, in that order, with no placeholders.
- `map-index` requires `features/README.md` to link every feature file, with no
  dead or unlinked files.
- `map-feature-shape` requires each feature file to have exactly four H2
  sections: `Sub-features`, `How to get to it (user POV)`,
  `Driving it with drive.sh`, `Gotchas`.
- `helpers-executable` requires `scripts/` to ship helpers and every helper to be
  executable.

## How to get to it (user POV)

- Read `.claude/skills/verify-cloud-coordinator/SKILL.md`.
- Browse the map at `.claude/skills/verify-cloud-coordinator/features/README.md`.
- Let CI's `Verification skill` job run the skill against this checkout.

## Driving it with drive.sh

Preconditions:

- `launch.sh` printed `launch: ready` and `doctor.sh` printed `doctor: READY`.

- **Validate the map.** Run `bash .claude/skills/verify-cloud-coordinator/scripts/drive.sh skill-map`.
  It exits `0`; `artifacts/verify/<run-id>/skill-map/skill-map.out` contains
  `check: skill verify-cloud-coordinator` and `OK: repository checks passed`, and
  `skill-map.exit` contains `0`.
- **Prove the shape check bites.** Run `bash .claude/skills/verify-cloud-coordinator/scripts/drive.sh gate-negative`.
  `skill-missing-gotchas.out` names `expected exactly 4 H2 sections`;
  `skill-placeholder.out` names `remove placeholder marker 'TODO'`.
- **Check the linked index.** Run `python3 - <<'PY'` with
  `from pathlib import Path; import re; ...` to list links in `features/README.md`
  and confirm both feature files resolve; or read the checker's `map-index` path
  via `python3 scripts/check_repo.py` failing when a link is removed.
- **Confirm helper permissions.** Run `ls -l .claude/skills/verify-cloud-coordinator/scripts`
  and confirm `launch.sh`, `doctor.sh`, `drive.sh`, and `cleanup.sh` are executable.
- **Evidence.** Confirm `artifacts/verify/<run-id>/skill-map/run.txt` records the
  revision and start time, and `skill-map.out` records the skill check line.

## Gotchas

- The skill lives under `.claude/skills/` for Claude Code; Cursor users read
  `.cursor/skills/` instead. This repository ships the Claude Code path only.
- Feature files must use exactly four H2 sections. Adding a fifth (say, a
  `Background` section) fails `map-feature-shape`; put context in the intro
  paragraph before the first H2.
- Frontmatter `name` must equal the directory name, or the skill never registers
  and the checker rejects it.
- The checker scans feature files for `TODO`, `FIXME`, `TBD`, `<app>`, and
  `<feature>`; quote such words only if you also update the placeholder list.
- `drive.sh skill-map` runs the whole checker, so a workflow regression also
  fails it. That is intentional: the skill and the gate that proves it ship
  together.
