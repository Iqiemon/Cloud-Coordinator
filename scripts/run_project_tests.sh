#!/usr/bin/env bash
# Run whatever test suite this repository has.
#
# CI calls this on every pull request and every push to the default branch.
# Today the repository has no tests, so the script says so and exits 0; the
# repository checks in scripts/check_repo.py still gate the run. As soon as a
# test command exists (package.json scripts.test, a Makefile `test` target, or
# pytest), this script runs it and CI fails with it.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"
ran=0

if [ -f package.json ] && node -e 'const p=require("./package.json"); process.exit(p.scripts && p.scripts.test ? 0 : 1)' 2>/dev/null; then
  echo "== npm test"
  npm test
  ran=1
fi

if [ -f Makefile ] && grep -qE '^test[[:space:]]*:' Makefile; then
  echo "== make test"
  make test
  ran=1
fi

if [ -f pyproject.toml ] || [ -d tests ]; then
  if python3 -c 'import pytest' 2>/dev/null; then
    echo "== python3 -m pytest -q"
    python3 -m pytest -q
    ran=1
  else
    echo "error: Python tests are present but pytest is not installed" >&2
    echo "install it with: python3 -m pip install -e '.[test]' (or pip install pytest)" >&2
    exit 1
  fi
fi

if [ "$ran" -eq 0 ]; then
  echo "no test suite configured yet; repository checks are the gate (scripts/check_repo.py)"
fi
