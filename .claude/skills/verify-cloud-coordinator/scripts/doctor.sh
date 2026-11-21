#!/usr/bin/env bash
# Doctor: one read-only check answering "is this instance worth driving?".
#
# Usage: bash .claude/skills/verify-cloud-coordinator/scripts/doctor.sh [run-dir]
#
# Checks the run environment from launch.sh, the checkout identity, the Python
# and PyYAML versions the checks need, and that no other verification run owns
# this checkout. Prints one line per check and exits 1 if any check fails.
# It never modifies the repository.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL_DIR="$REPO_ROOT/.claude/skills/verify-cloud-coordinator"
RUN_DIR="${1:-${VERIFY_RUN_DIR:-$(cat "$SKILL_DIR/.last-run" 2>/dev/null || true)}}"

failures=0
check() {
  local status="$1" message="$2"
  printf '%-4s %s\n' "$status" "$message"
  if [ "$status" = "FAIL" ]; then failures=$((failures + 1)); fi
}

if [ -z "$RUN_DIR" ] || [ ! -f "$RUN_DIR/run.env" ]; then
  check FAIL "run environment: no run.env (run scripts/launch.sh first)"
else
  check OK "run environment: $RUN_DIR"
  # shellcheck disable=SC1091
  . "$RUN_DIR/run.env"
  if [ "$repo_root" = "$REPO_ROOT" ]; then
    check OK "checkout: $REPO_ROOT"
  else
    check FAIL "checkout: run belongs to $repo_root, not $REPO_ROOT"
  fi
  current="$(git rev-parse HEAD)"
  if [ "$current" = "$revision" ]; then
    check OK "revision: ${current:0:12} ($branch)"
  else
    check FAIL "revision: checkout moved from ${revision:0:12} to ${current:0:12}; relaunch"
  fi
fi

set +e
python3 - <<'PY'
import sys
ok = sys.version_info >= (3, 10)
print(("OK  " if ok else "FAIL") + f" python: {sys.version.split()[0]} (need >= 3.10)")
try:
    import yaml
    print(f"OK   pyyaml: {yaml.__version__}")
except ModuleNotFoundError:
    ok = False
    print("FAIL pyyaml: not installed (pip install -r requirements-dev.txt)")
sys.exit(0 if ok else 1)
PY
python_status=$?
set -e
if [ "$python_status" -ne 0 ]; then failures=$((failures + 1)); fi

if command -v git >/dev/null 2>&1; then
  check OK "git: $(git --version)"
else
  check FAIL "git: not on PATH"
fi

if [ -n "${RUN_DIR:-}" ] && [ -f "$RUN_DIR/run.env" ]; then
  other="$(cat "$SKILL_DIR/.last-run" 2>/dev/null || true)"
  if [ "$other" = "$RUN_DIR" ]; then
    check OK "ownership: this run owns the checkout"
  else
    check FAIL "ownership: .last-run points at ${other:-nothing}; relaunch this run"
  fi
fi

if [ "$failures" -gt 0 ]; then
  echo "doctor: NOT READY ($failures failure(s))"
  exit 1
fi
echo "doctor: READY"
