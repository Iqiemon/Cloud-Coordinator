#!/usr/bin/env bash
# Cleanup: remove the scratch state a verification run created.
#
# Usage: bash .claude/skills/verify-cloud-coordinator/scripts/cleanup.sh
#
# Removes the run directory from /tmp and the .last-run pointer, and drops the
# launch check log. It never touches artifacts/verify/: proof artifacts must
# survive teardown. It never kills processes it did not start.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL_DIR="$REPO_ROOT/.claude/skills/verify-cloud-coordinator"
POINTER="$SKILL_DIR/.last-run"
RUN_DIR="$(cat "$POINTER" 2>/dev/null || true)"

if [ -n "$RUN_DIR" ]; then
  case "$RUN_DIR" in
    /tmp/verify-cloud-coordinator/*) rm -rf "$RUN_DIR" ;;
    *) echo "cleanup: refusing to remove unexpected path $RUN_DIR" >&2 ;;
  esac
fi
rm -f "$POINTER"

echo "cleanup: removed run scratch"
if [ -d "$REPO_ROOT/artifacts/verify" ]; then
  echo "cleanup: evidence kept at artifacts/verify/"
  find "$REPO_ROOT/artifacts/verify" -mindepth 1 -maxdepth 1 -type d | sed 's/^/  /'
fi
