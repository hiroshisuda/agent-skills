#!/usr/bin/env bash
# Shared helpers for the code plugin's hooks. Source this file; don't run it.

# shellcheck disable=SC2034 # used by the scripts in lang/
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DATA_DIR="${CLAUDE_PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/hiroshisuda-code}"

# Findings block Claude until fixed; notes are context that doesn't block.
FINDINGS=""
NOTES=""

# Print a string field from the hook's JSON input. $1 is a jq path such as .tool_input.file_path.
json_field() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$HOOK_INPUT" | jq -r "$1 // empty"
  else
    local key="${1##*.}"
    printf '%s' "$HOOK_INPUT" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
  fi
}

json_escape() {
  awk 'BEGIN { ORS = "" }
    { gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "\\r")
      if (NR > 1) print "\\n"; print }'
}

# Absolute, symlink-free path of an existing file.
abs_path() {
  printf '%s/%s' "$(cd "$(dirname "$1")" && pwd -P)" "$(basename "$1")"
}

# Walk up from directory $1, printing the first directory for which predicate $2 succeeds.
find_up() {
  local dir="$1" pred="$2"
  while :; do
    if "$pred" "$dir"; then
      printf '%s' "$dir"
      return 0
    fi
    [ "$dir" = / ] && return 1
    dir=$(dirname "$dir")
  done
}

# The git work tree containing directory $1, or $1 itself.
project_root() {
  git -C "$1" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$1"
}

# $1 relative to directory $2 when it's inside it, else $1 unchanged.
rel_to() {
  case "$1" in
    "$2"/*) printf '%s' "${1#"$2"/}" ;;
    *) printf '%s' "$1" ;;
  esac
}

add_findings() { # tool, text
  FINDINGS="${FINDINGS}== $1 ==
$2

"
}

add_note() {
  NOTES="${NOTES}- $1
"
}

# Per-session state, so notes appear once and error counts can be compared between writes.
state_file() { # key
  local session key
  session=$(json_field .session_id)
  key=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
  mkdir -p "$DATA_DIR/state/${session:-nosession}"
  printf '%s' "$DATA_DIR/state/${session:-nosession}/$key"
}

# Add a note only the first time this session sees key $1.
note_once() { # key, text
  local f
  f=$(state_file "note:$1")
  [ -e "$f" ] && return 0
  : >"$f"
  add_note "$2"
}

# Report diagnostics from a project-wide type checker.
# $1 tool name, $2 its output (one diagnostic per line), $3 prefix that marks lines about the
# edited file, $4 project directory, $5 command that shows every diagnostic.
# Lines for the edited file are findings, and so are lines for other files that the previous check
# this session didn't report. The rest are counted; the first check of the session notes them.
report_project_diagnostics() {
  local tool="$1" out="$2" prefix="$3" dir="$4" cmd="$5"
  local mine others new seen first="" count
  mine=$(printf '%s\n' "$out" | P="$prefix" awk 'NF && index($0, ENVIRON["P"]) == 1')
  others=$(printf '%s\n' "$out" | P="$prefix" awk 'NF && index($0, ENVIRON["P"]) != 1')
  count=$(printf '%s' "$others" | grep -c . || true)

  seen=$(state_file "seen:$tool:$dir")
  if [ -f "$seen" ]; then
    new=$(printf '%s\n' "$others" | awk 'NR == FNR { seen[$0]; next } NF && !($0 in seen)' "$seen" -)
  else
    first=1
    new=""
  fi
  printf '%s\n' "$out" >"$seen"

  local elsewhere=""
  [ "$count" -gt 0 ] &&
    elsewhere="$tool reports $count diagnostic(s) in other files under $dir. See them with: (cd '$dir' && $cmd)"

  if [ -n "$new" ]; then
    mine="${mine:+$mine
}Other files, new since the last check (fix the ones this edit caused):
$new"
  fi
  if [ -n "$mine" ]; then
    add_findings "$tool" "$mine${elsewhere:+

$elsewhere}"
  elif [ -n "$first" ] && [ -n "$elsewhere" ]; then
    add_note "$elsewhere They predate this session's first check. Fix them when they're in code you're working on."
  fi
}

# Send findings back to Claude (exit 2) or notes as context (exit 0).
emit_report() { # file
  if [ -n "$FINDINGS" ]; then
    {
      printf 'Code checks flagged %s. Fix every finding at its cause, following the coding conventions. Suppress a rule only for a false positive, scoped to that line and rule, with a comment giving the reason.\n\n%s' "$1" "$FINDINGS"
      [ -n "$NOTES" ] && printf 'Notes:\n%s' "$NOTES"
    } >&2
    exit 2
  fi
  if [ -n "$NOTES" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' \
      "$(printf 'Code checks on %s:\n%s' "$1" "$NOTES" | json_escape)"
  fi
  exit 0
}
