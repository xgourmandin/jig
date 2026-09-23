#!/usr/bin/env bash
# SessionStart: warn (in Claude's context) when required binaries are missing,
# so Claude tells the user instead of silently degrading.
set -uo pipefail
git ls-files '*.tf' 2>/dev/null | grep -q . || ls ./*.tf >/dev/null 2>&1 || exit 0
missing=()
for bin in terraform terraform-ls tflint; do
  command -v "$bin" >/dev/null || missing+=("$bin")
done
if (( ${#missing[@]} )); then
  echo "ACME terraform: missing tools: ${missing[*]}. Tell the user to run 'mise install' in this repo. Code intelligence and edit checks are degraded until then."
fi
