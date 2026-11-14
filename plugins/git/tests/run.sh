#!/usr/bin/env bash
# Run every test file in this directory.
status=0
for test in "$(dirname "$0")"/*.test.sh; do
  "$test" || status=1
done
exit "$status"
