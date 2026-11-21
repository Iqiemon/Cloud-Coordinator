#!/usr/bin/env bash
# Drive: exercise a feature from the verification map and capture evidence.
#
# Usage: bash .claude/skills/verify-cloud-coordinator/scripts/drive.sh <feature>
#
# Features (see ../features/):
#   gate           Run the repository checks on this checkout; expect PASS.
#   gate-negative  Copy the checkout, break the CI workflow and the verification
#                  skill one at a time, and require the checks to FAIL each time.
#                  Proves a passing gate is not an unconditional pass.
#   skill-map      Validate the verification skill and feature map alone.
#
# Evidence lands in artifacts/verify/<run-id>/<feature>/ and survives cleanup.
# Exit status is 0 when the expected result was observed, 1 otherwise.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
SKILL_DIR="$REPO_ROOT/.claude/skills/verify-cloud-coordinator"

FEATURE="${1:?usage: drive.sh <gate|gate-negative|skill-map>}"
RUN_DIR="$(cat "$SKILL_DIR/.last-run" 2>/dev/null || true)"
if [ -z "$RUN_DIR" ] || [ ! -f "$RUN_DIR/run.env" ]; then
  echo "drive: no launch found; run scripts/launch.sh first" >&2
  exit 1
fi
# shellcheck disable=SC1091
. "$RUN_DIR/run.env"

EVIDENCE="$REPO_ROOT/artifacts/verify/$run_id/$FEATURE"
mkdir -p "$EVIDENCE"
printf 'feature=%s\nrevision=%s\nstarted_at=%s\n' \
  "$FEATURE" "$(git rev-parse HEAD)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > "$EVIDENCE/run.txt"

scratch=""
trap '[ -n "$scratch" ] && rm -rf "$scratch"' EXIT

# Copy the checkout without .git or dependency directories into $scratch.
# The caller sets $scratch so the EXIT trap can remove it; a command
# substitution would hide the assignment in a subshell and leak the copy.
make_scratch_copy() {
  mkdir -p "$scratch"
  tar -C "$REPO_ROOT" \
    --exclude=./.git --exclude=./node_modules --exclude=./artifacts --exclude=./.verify \
    -cf - . | tar -C "$scratch" -xf -
  git -C "$scratch" init -q
  git -C "$scratch" add -A
  git -C "$scratch" -c user.name=verify -c user.email=verify@example.invalid \
    commit -qm "verification scratch copy"
}

# run_check <label> <repo-dir> <expected-exit> -> records output, returns 0 if expected
run_check() {
  local label="$1" dir="$2" expected="$3" status
  set +e
  ( cd "$dir" && python3 scripts/check_repo.py ) > "$EVIDENCE/$label.out" 2>&1
  status=$?
  set -e
  echo "$status" > "$EVIDENCE/$label.exit"
  if [ "$status" -eq "$expected" ]; then
    echo "  OK   $label (exit $status)"
    return 0
  fi
  echo "  FAIL $label (exit $status, expected $expected)" >&2
  sed 's/^/       /' "$EVIDENCE/$label.out" >&2
  return 1
}

case "$FEATURE" in
  gate)
    echo "drive: gate on $REPO_ROOT"
    run_check gate "$REPO_ROOT" 0
    set +e
    ( cd "$REPO_ROOT" && bash scripts/run_project_tests.sh ) > "$EVIDENCE/project-tests.out" 2>&1
    tests_status=$?
    set -e
    echo "$tests_status" > "$EVIDENCE/project-tests.exit"
    if [ "$tests_status" -ne 0 ]; then
      echo "  FAIL project-tests (exit $tests_status)" >&2
      exit 1
    fi
    echo "  OK   project-tests (exit 0)"
    echo "evidence: $EVIDENCE"
    ;;

  gate-negative)
    echo "drive: gate-negative"
    scratch="$(mktemp -d "$RUN_DIR/scratch.XXXXXX")"
    make_scratch_copy
    copy="$scratch"
    run_check baseline "$copy" 0

    # 1. Remove the pull_request trigger.
    python3 - "$copy/.github/workflows/ci.yml" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace("  pull_request:\n", "", 1))
PY
    run_check workflow-no-pull-request "$copy" 1
    git -C "$copy" checkout -q -- .github/workflows/ci.yml

    # 2. Point a step at a script that does not exist.
    python3 - "$copy/.github/workflows/ci.yml" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(
    text.replace("bash scripts/run_project_tests.sh", "bash scripts/missing.sh", 1)
)
PY
    run_check workflow-missing-script "$copy" 1
    git -C "$copy" checkout -q -- .github/workflows/ci.yml

    # 3. Unpin an action to a floating ref.
    python3 - "$copy/.github/workflows/ci.yml" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace("actions/checkout@v4", "actions/checkout@main", 1))
PY
    run_check workflow-unpinned-action "$copy" 1
    git -C "$copy" checkout -q -- .github/workflows/ci.yml

    # 4. Delete a required section from a feature file.
    feature_file="$(ls "$copy"/.claude/skills/verify-cloud-coordinator/features/*.md | grep -v README | head -1)"
    python3 - "$feature_file" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
head, _, _ = text.partition("## Gotchas")
open(path, "w", encoding="utf-8").write(head.rstrip() + "\n")
PY
    run_check skill-missing-gotchas "$copy" 1
    git -C "$copy" checkout -q -- .

    # 5. Leave a placeholder in the skill body.
    printf '\nTODO: fill this in\n' >> "$copy/.claude/skills/verify-cloud-coordinator/SKILL.md"
    run_check skill-placeholder "$copy" 1
    git -C "$copy" checkout -q -- .

    echo "evidence: $EVIDENCE"
    ;;

  skill-map)
    echo "drive: skill-map"
    python3 scripts/check_repo.py > "$EVIDENCE/skill-map.out" 2>&1
    echo "$?" > "$EVIDENCE/skill-map.exit"
    grep -q 'skill verify-cloud-coordinator' "$EVIDENCE/skill-map.out"
    echo "evidence: $EVIDENCE"
    ;;

  *)
    echo "drive: unknown feature $FEATURE (see features/README.md)" >&2
    exit 1
    ;;
esac

echo "drive: $FEATURE passed"
