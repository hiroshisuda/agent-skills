#!/usr/bin/env bash
# Terraform checks: terraform fmt formats the edited file; TFLint fixes and lints it.
# Fast checks only: terraform validate needs `terraform init`, so it's left to CI.
# Sourced by post-write.sh.

TF_CONFIG="$PLUGIN_ROOT/config/terraform"

has_tflint_config() { [ -f "$1/.tflint.hcl" ]; }

check_terraform() { # absolute file path
  local file="$1" dir tf cfg out

  dir=$(dirname "$file")

  tf=$(command -v terraform || command -v tofu)
  if [ -n "$tf" ] && ! out=$("$tf" fmt -no-color "$file" 2>&1); then
    # fmt fails only when the file doesn't parse, so its output is the syntax error.
    add_findings "$(basename "$tf") fmt" "$out"
    return
  fi

  case "$file" in *.tf) ;; *) return ;; esac
  command -v tflint >/dev/null 2>&1 || return

  if cfg=$(find_up "$dir" has_tflint_config); then
    cfg="$cfg/.tflint.hcl"
  else
    cfg="$TF_CONFIG/tflint.hcl"
    note_once "tflint:$dir" "No .tflint.hcl covers $dir, so TFLint used the code plugin's strict defaults ($cfg). Suggest to the user adding a .tflint.hcl based on it, with the plugin for their cloud provider."
  fi
  # --force exits 0 when issues are found, so a nonzero exit means TFLint itself failed.
  if ! out=$(tflint --chdir="$dir" --config="$cfg" --filter="$(basename "$file")" --fix \
    --format=compact --no-color --force 2>&1); then
    add_note "tflint failed on $file: $out (if it names a missing plugin, the user should run 'tflint --init' in $dir)"
    return
  fi
  out=$(printf '%s\n' "$out" | grep -E '^[^[:space:]].*:[0-9]+:[0-9]+: ' || true)
  [ -n "$out" ] && add_findings tflint "$out"
}
