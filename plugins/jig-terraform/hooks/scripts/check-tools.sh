#!/usr/bin/env bash
# SessionStart: warn (in Claude's context) when required binaries are missing,
# so Claude tells the user instead of silently degrading.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
git ls-files '*.tf' 2>/dev/null | grep -q . || ls ./*.tf >/dev/null 2>&1 || exit 0
missing=()
jig_tf_bin >/dev/null || missing+=("terraform or tofu")
for bin in terraform-ls tflint; do
  command -v "$bin" >/dev/null || missing+=("$bin")
done
if (( ${#missing[@]} )); then
  list="$(IFS=,; echo "${missing[*]}")"
  echo "Jig terraform: missing tools: ${list//,/, }. Tell the user to run 'mise install' in this repo. Code intelligence and edit checks are degraded until then."
fi
