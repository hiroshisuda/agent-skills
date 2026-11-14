#!/usr/bin/env bash
# Assertions shared by the git plugin's tests. Source this file; don't run it.

failures=0

check() { # description, expected, actual
  if [ "$2" != "$3" ]; then
    printf 'FAIL: %s\n  expected: %q\n  actual:   %q\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

# Print the result and exit non-zero if any check failed.
finish() {
  if [ "$failures" -gt 0 ]; then
    echo "$(basename "$0"): $failures failed"
    exit 1
  fi
  echo "$(basename "$0"): all passed"
}
