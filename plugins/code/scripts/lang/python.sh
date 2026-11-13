#!/usr/bin/env bash
# Python checks: ruff lints the edited file; ty type checks its project. Sourced by post-write.sh.

PY_CONFIG="$PLUGIN_ROOT/config/python"

has_pyproject() { [ -f "$1/pyproject.toml" ]; }
has_ruff_config() {
  [ -f "$1/ruff.toml" ] || [ -f "$1/.ruff.toml" ] ||
    { [ -f "$1/pyproject.toml" ] && grep -q '^\[tool\.ruff' "$1/pyproject.toml"; }
}
has_ty_config() {
  [ -f "$1/ty.toml" ] ||
    { [ -f "$1/pyproject.toml" ] && grep -q '^\[tool\.ty' "$1/pyproject.toml"; }
}

# Print the command for a Python tool: the project's virtualenv, then PATH, then uvx.
py_tool() { # name, project dir
  if [ -x "$2/.venv/bin/$1" ]; then
    printf '%s' "$2/.venv/bin/$1"
  elif command -v "$1" >/dev/null 2>&1; then
    printf '%s' "$1"
  elif command -v uvx >/dev/null 2>&1; then
    printf 'uvx -q %s' "$1"
  fi
}

# Keep only "path:line:col: ..." diagnostic lines.
diagnostic_lines() { grep -E '^[^[:space:]].*:[0-9]+:[0-9]+: ' || true; }

check_python() { # absolute file path
  local file="$1" dir root cfg_dir ruff ty out status args

  dir=$(dirname "$file")
  root=$(find_up "$dir" has_pyproject) || root=$(project_root "$dir")

  ruff=$(py_tool ruff "$root")
  if [ -n "$ruff" ]; then
    args=(check --output-format concise --no-fix)
    if ! cfg_dir=$(find_up "$dir" has_ruff_config); then
      args+=(--config "$PY_CONFIG/ruff.toml")
      note_once "ruff:$root" "No ruff config covers $root, so ruff used the code plugin's strict defaults ($PY_CONFIG/ruff.toml). Suggest to the user adding a [tool.ruff] section to pyproject.toml with strict rules, based on those defaults."
      cfg_dir="$root"
    fi
    out=$(cd "$cfg_dir" && $ruff "${args[@]}" "$file" 2>&1)
    status=$?
    if [ "$status" -ge 2 ]; then
      add_note "ruff failed on $file (exit $status): $out"
    else
      out=$(printf '%s\n' "$out" | diagnostic_lines)
      [ -n "$out" ] && add_findings ruff "$out"
    fi
  fi

  ty=$(py_tool ty "$root")
  if [ -n "$ty" ]; then
    args=(check --output-format concise --no-progress --color never)
    if ! cfg_dir=$(find_up "$dir" has_ty_config); then
      args+=(--config-file "$PY_CONFIG/ty.toml")
      note_once "ty:$root" "No ty config covers $root, so ty used the code plugin's strict defaults ($PY_CONFIG/ty.toml: every rule is an error). Suggest to the user adding a [tool.ty.rules] section to pyproject.toml with all = \"error\"."
      cfg_dir="$root"
    fi
    out=$(cd "$cfg_dir" && $ty "${args[@]}" 2>&1)
    status=$?
    if [ "$status" -ge 2 ]; then
      add_note "ty failed on $cfg_dir (exit $status): $out"
    else
      report_project_diagnostics ty "$(printf '%s\n' "$out" | diagnostic_lines)" \
        "$(rel_to "$file" "$cfg_dir"):" "$cfg_dir" "$ty ${args[*]}"
    fi
  fi
}
