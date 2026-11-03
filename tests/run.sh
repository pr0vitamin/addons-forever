#!/usr/bin/env bash
# Runs every test_* function in tests/test_*.sh, each in its own subshell.
# Usage: tests/run.sh [name-filter]
# Must run on bash 3.2 (macOS) as well as Git Bash on Windows.

set -uo pipefail
export LC_ALL=C

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
filter=${1:-}

pass=0
fail=0
skip=0

for file in "$TESTS_DIR"/test_*.sh; do
  names=$("$BASH" -c "source '$TESTS_DIR/lib.sh'; source '$file'; declare -F" | awk '{print $3}' | grep '^test_' || true)
  for name in $names; do
    case "$name" in *"$filter"*) ;; *) continue ;; esac
    out=$("$BASH" -c "set -euo pipefail; source '$TESTS_DIR/lib.sh'; source '$file'; setup_tmp; $name" 2>&1)
    status=$?
    if [ $status -eq 0 ]; then
      pass=$((pass + 1)); printf 'ok    %s\n' "$name"
    elif [ $status -eq 77 ]; then
      skip=$((skip + 1)); printf 'skip  %s (%s)\n' "$name" "$(printf '%s' "$out" | tail -n 1)"
    else
      fail=$((fail + 1)); printf 'FAIL  %s\n' "$name"; printf '%s\n' "$out" | sed 's/^/      /'
    fi
  done
done

printf '\n%d passed, %d failed, %d skipped\n' "$pass" "$fail" "$skip"
[ $fail -eq 0 ]
