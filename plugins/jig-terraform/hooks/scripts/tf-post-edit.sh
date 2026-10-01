#!/usr/bin/env bash
# PostToolUse: after Claude edits a .tf/.tfvars file, auto-format it and lint
# its module directory. Exit 2 + stderr feeds problems back to Claude.
# Also records the module dir so the Stop hook can validate it.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[[ "$file" =~ \.(tf|tfvars)$ ]] || exit 0
[[ -f "$file" ]] || exit 0

dir="$(cd "$(dirname -- "$file")" && pwd)"
problems=""

# 0. Remember this module for validation at Stop (see tf-stop-validate.sh).
if [[ "$file" == *.tf ]]; then
  sid="$(jq -r '.session_id // empty' <<<"$input")"
  state="$(jig_tf_session_file "$sid")"
  mkdir -p "$(dirname "$state")"
  grep -qxF "$dir" "$state" 2>/dev/null || printf '%s\n' "$dir" >>"$state"
fi

# 1. terraform/tofu fmt: fixes formatting in place; reports syntax errors.
if tf="$(jig_tf_bin)"; then
  if ! out="$("$tf" fmt -no-color "$file" 2>&1 >/dev/null)"; then
    problems+="$tf fmt failed (likely HCL syntax error):"$'\n'"$out"$'\n'
  fi
fi

# 2. tflint on the module directory (only for .tf files).
if [[ "$file" == *.tf ]] && command -v tflint >/dev/null; then
  # Use the nearest .tflint.hcl up the tree (tflint only reads the one in the module dir).
  cfg=(); d="$dir"
  while [[ "$d" != / ]]; do
    [[ -f "$d/.tflint.hcl" ]] && { cfg=(--config="$d/.tflint.hcl"); break; }
    d="$(dirname "$d")"
  done
  if ! out="$(tflint --chdir="$dir" "${cfg[@]}" --format=compact --no-color 2>&1)"; then
    problems+=$'tflint reported issues:\n'"$out"$'\n'
  fi
fi

if [[ -n "$problems" ]]; then
  printf 'Jig terraform checks for %s:\n%s' "$file" "$problems" >&2
  exit 2
fi
exit 0
