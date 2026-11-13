#!/usr/bin/env bash
# PostToolUse (Write|Edit|MultiEdit): fix, format, lint, and type check the written file with its
# language's tools.
# Findings go back to Claude through stderr with exit code 2; notes go back as context.
# To add a language, add scripts/lang/<language>.sh with a check_<language> function and a case below.
set -u

HOOK_INPUT=$(cat)
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

file=$(json_field .tool_input.file_path)
[ -n "$file" ] && [ -f "$file" ] || exit 0

case "$file" in
  *.py | *.pyi) lang=python ;;
  *.ts | *.tsx | *.mts | *.cts) lang=typescript ;;
  *.tf | *.tfvars) lang=terraform ;;
  *) exit 0 ;;
esac
case "/$file/" in
  */node_modules/* | */.venv/* | */.terraform/*) exit 0 ;;
esac

file=$(abs_path "$file")
# shellcheck source=/dev/null
. "$(dirname "$0")/lang/$lang.sh"
"check_$lang" "$file"
emit_report "$file"
