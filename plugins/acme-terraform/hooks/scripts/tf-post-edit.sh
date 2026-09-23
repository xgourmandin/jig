#!/usr/bin/env bash
# PostToolUse: after Claude edits a .tf/.tfvars file, auto-format it and lint
# its module directory. Exit 2 + stderr feeds problems back to Claude.
set -uo pipefail
input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[[ "$file" =~ \.(tf|tfvars)$ ]] || exit 0
[[ -f "$file" ]] || exit 0

dir="$(dirname -- "$file")"
problems=""

# 1. terraform fmt: fixes formatting in place; reports syntax errors.
if command -v terraform >/dev/null; then
  if ! out="$(terraform fmt -no-color "$file" 2>&1 >/dev/null)"; then
    problems+=$'terraform fmt failed (likely HCL syntax error):\n'"$out"$'\n'
  fi
fi

# 2. tflint on the module directory (only for .tf files).
if [[ "$file" == *.tf ]] && command -v tflint >/dev/null; then
  if ! out="$(tflint --chdir="$dir" --format=compact --no-color 2>&1)"; then
    problems+=$'tflint reported issues:\n'"$out"$'\n'
  fi
fi

if [[ -n "$problems" ]]; then
  printf 'ACME terraform checks for %s:\n%s' "$file" "$problems" >&2
  exit 2
fi
exit 0
