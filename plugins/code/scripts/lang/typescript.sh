#!/usr/bin/env bash
# TypeScript checks: eslint lints the edited file; tsc type checks its project. Sourced by post-write.sh.

TS_CONFIG="$PLUGIN_ROOT/config/typescript"
TS_FALLBACK="$DATA_DIR/typescript"

has_tsconfig() { [ -f "$1/tsconfig.json" ]; }
has_eslint_config() {
  local ext
  for ext in js mjs cjs ts mts cts; do
    [ -f "$1/eslint.config.$ext" ] && return 0
  done
  return 1
}

# Install the pinned fallback toolchain into the data directory, or update it when the shipped
# files change. Prints nothing and fails when npm is missing or the install fails.
ts_fallback_ready() {
  local f stale=""
  for f in package.json package-lock.json eslint.config.mjs; do
    cmp -s "$TS_CONFIG/$f" "$TS_FALLBACK/$f" || stale=1
  done
  [ -z "$stale" ] && [ -x "$TS_FALLBACK/node_modules/.bin/eslint" ] && return 0
  command -v npm >/dev/null 2>&1 || return 1

  local tmp="$TS_FALLBACK.tmp.$$" out
  rm -rf "$tmp" && mkdir -p "$tmp"
  for f in package.json package-lock.json eslint.config.mjs; do cp "$TS_CONFIG/$f" "$tmp/"; done
  if ! out=$(cd "$tmp" && npm ci --no-audit --no-fund --loglevel=error 2>&1); then
    rm -rf "$tmp"
    add_note "Installing the code plugin's fallback TypeScript toolchain failed, so the fallback eslint and tsc were skipped: $out"
    return 1
  fi
  rm -rf "$TS_FALLBACK" && mv "$tmp" "$TS_FALLBACK"
}

# Print the command for a Node tool: the project's node_modules, then PATH, then the fallback.
ts_tool() { # name, start dir
  local dir
  dir=$(find_up "$2" "has_bin_$1") && { printf '%s' "$dir/node_modules/.bin/$1"; return; }
  command -v "$1" >/dev/null 2>&1 && { printf '%s' "$1"; return; }
  ts_fallback_ready && printf '%s' "$TS_FALLBACK/node_modules/.bin/$1"
}
has_bin_tsc() { [ -x "$1/node_modules/.bin/tsc" ]; }
has_bin_eslint() { [ -x "$1/node_modules/.bin/eslint" ]; }

# tsc prints multi-line messages with indented continuation lines; join them onto one line.
join_tsc_lines() {
  awk '/^[[:space:]]/ && NR > 1 { sub(/^[[:space:]]+/, " "); line = line $0; next }
       { if (NR > 1) print line; line = $0 }
       END { if (NR) print line }'
}

check_typescript() { # absolute file path
  local file="$1" dir root tsdir cfg_dir eslint tsc out status cmd
  local typed=0

  dir=$(dirname "$file")
  root=$(project_root "$dir")
  tsdir=$(find_up "$dir" has_tsconfig) && typed=1

  if cfg_dir=$(find_up "$dir" has_eslint_config); then
    eslint=$(ts_tool eslint "$dir")
  else
    cfg_dir="$root"
    note_once "eslint:$root" "No ESLint config covers $root, so eslint used the code plugin's strict defaults ($TS_CONFIG/eslint.config.mjs). Suggest to the user adding an eslint.config.mjs with typescript-eslint's strictTypeChecked and stylisticTypeChecked presets."
    ts_fallback_ready && eslint="$TS_FALLBACK/node_modules/.bin/eslint --config $TS_FALLBACK/eslint.config.mjs"
  fi
  if [ -n "$eslint" ]; then
    out=$(cd "$cfg_dir" && CODE_PLUGIN_TYPED=$typed $eslint --format "$TS_CONFIG/formatter.cjs" --no-warn-ignored "$file" 2>&1)
    status=$?
    if [ "$status" -ge 2 ]; then
      add_note "eslint failed on $file (exit $status): $out"
    elif [ -n "$out" ]; then
      add_findings eslint "$out"
    fi
  fi

  if [ "$typed" = 1 ]; then
    tsc=$(ts_tool tsc "$dir")
    [ -z "$tsc" ] && return
    cmd="$tsc --noEmit --pretty false -p tsconfig.json"
    out=$(cd "$tsdir" && $cmd 2>&1 | join_tsc_lines)
    report_project_diagnostics tsc "$out" "$(rel_to "$file" "$tsdir")(" "$tsdir" "$cmd"
  else
    note_once "tsc:$root" "No tsconfig.json covers $file, so tsc checked it alone with the code plugin's strict flags. Suggest to the user adding a tsconfig.json with strict, noUncheckedIndexedAccess, exactOptionalPropertyTypes, noImplicitOverride, and noFallthroughCasesInSwitch."
    tsc=$(ts_tool tsc "$dir")
    [ -z "$tsc" ] && return
    out=$(cd "$root" && $tsc --noEmit --pretty false --strict --noUncheckedIndexedAccess \
      --exactOptionalPropertyTypes --noImplicitOverride --noFallthroughCasesInSwitch \
      --target es2022 --module nodenext --jsx react-jsx --skipLibCheck "$file" 2>&1 | join_tsc_lines)
    report_project_diagnostics tsc "$out" "$(rel_to "$file" "$root")(" "$root" "tsc --strict $(rel_to "$file" "$root")"
  fi
}
