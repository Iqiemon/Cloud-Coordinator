#!/usr/bin/env bash
# Launch: prepare an isolated environment for this verification run.
#
# There is no long-lived app to start yet: Cloud-Coordinator's user-facing
# surfaces today are the repository's own checks and the verification skill.
# Launch therefore creates a private scratch directory, installs the one Python
# dependency the checks need, and records the environment for later steps.
#
# Usage: bash .claude/skills/verify-cloud-coordinator/scripts/launch.sh [run-id]
#
# Output: prints the run directory. Teardown: scripts/cleanup.sh.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

RUN_ID="${1:-$(date -u +%Y%m%dT%H%M%SZ)}"
SKILL_DIR="$REPO_ROOT/.claude/skills/verify-cloud-coordinator"
RUN_DIR="${VERIFY_RUN_DIR:-/tmp/verify-cloud-coordinator/$RUN_ID}"

mkdir -p "$RUN_DIR"
printf '%s\n' "$RUN_DIR" > "$SKILL_DIR/.last-run"

if ! python3 -c 'import yaml' 2>/dev/null; then
  echo "install: PyYAML is missing; installing into the user environment"
  python3 -m pip install --quiet --disable-pip-version-check --user -r requirements-dev.txt \
    || python3 -m pip install --quiet --disable-pip-version-check --user \
      --break-system-packages -r requirements-dev.txt
  python3 -c 'import yaml' || { echo "launch: PyYAML install failed" >&2; exit 1; }
fi

python3 scripts/check_repo.py > "$RUN_DIR/launch.check_repo.log" 2>&1 || {
  echo "launch: baseline repository checks FAIL" >&2
  cat "$RUN_DIR/launch.check_repo.log" >&2
  echo "launch: fix the checkout before driving it" >&2
  exit 1
}

{
  echo "run_id=$RUN_ID"
  echo "run_dir=$RUN_DIR"
  echo "repo_root=$REPO_ROOT"
  echo "revision=$(git rev-parse HEAD)"
  echo "branch=$(git symbolic-ref --short -q HEAD || echo detached)"
  echo "started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "pid=$$"
} > "$RUN_DIR/run.env"

echo "launch: ready"
echo "$RUN_DIR"
