#!/usr/bin/env bash
# SessionStart: load the coding conventions, and tell Claude which checks can't run here.
root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
cat "$root/CONVENTIONS.md"

missing=()
if ! command -v uvx >/dev/null 2>&1; then
  for tool in ruff ty; do
    command -v "$tool" >/dev/null 2>&1 || missing+=("$tool")
  done
  [ ${#missing[@]} -gt 0 ] && missing=("Python: $(printf "%s" "${missing[*]}" | sed "s/ / and /") (install uv from https://docs.astral.sh/uv/, and the hook runs them with uvx)")
fi
command -v npm >/dev/null 2>&1 ||
  missing+=("TypeScript: npm (needed for projects without their own eslint and tsc)")
tf=()
command -v terraform >/dev/null 2>&1 || command -v tofu >/dev/null 2>&1 || tf+=("terraform (or tofu)")
command -v tflint >/dev/null 2>&1 || tf+=("tflint (https://github.com/terraform-linters/tflint)")
[ ${#tf[@]} -gt 0 ] && missing+=("Terraform: $(printf "%s" "${tf[*]}" | sed "s/) /) and /")")
if [ ${#missing[@]} -gt 0 ]; then
  printf '\nNote from the code plugin, relevant only if you write these languages: some checks are unavailable. %s. Tell the user once, when you first write such a file.\n' "$(printf '%s. ' "${missing[@]}" | sed 's/\. $//')"
fi
exit 0
