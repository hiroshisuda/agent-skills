#!/usr/bin/env bash
# PostToolUse (Write|Edit|MultiEdit): lint the written .md file with vale-ai-tells.
# Findings go back to Claude through stderr with exit code 2; everything else exits quietly.
set -u

input=$(cat)
if command -v jq >/dev/null 2>&1; then
  file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')
else
  file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)
fi

case "$file" in
  *.md) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0
# check-vale.sh reports a missing vale at session start.
command -v vale >/dev/null 2>&1 || exit 0

data="${CLAUDE_PLUGIN_DATA:-${XDG_CACHE_HOME:-$HOME/.cache}/hiroshisuda-docs}"
config="$data/.vale.ini"
src="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}/vale/vale.ini"

# Install or update the styles when the shipped config changes.
if ! cmp -s "$src" "$config" || [ ! -d "$data/styles/ai-tells" ]; then
  mkdir -p "$data"
  cp "$src" "$config.tmp"
  if ! sync_out=$(vale --config "$config.tmp" sync 2>&1); then
    rm -f "$config.tmp"
    echo "docs plugin: 'vale sync' failed, so $file was not checked: $sync_out" >&2
    exit 1
  fi
  mv "$config.tmp" "$config"
fi

if ! out=$(vale --config "$config" --output=line --no-wrap --no-exit "$file" 2>&1); then
  echo "docs plugin: vale failed on $file: $out" >&2
  exit 1
fi
[ -z "$out" ] && exit 0

cat >&2 <<EOF
Vale (vale-ai-tells) flagged $file. Fix every finding by rewriting the passage in place, following the writing-docs skill. Don't add vale suppression comments unless a finding is a false positive, such as a quoted term or a literal name.

$out
EOF
exit 2
