#!/usr/bin/env bash
# SessionStart: warn (in Claude's context) when required binaries are missing,
# so Claude tells the user instead of silently degrading.
set -uo pipefail
git ls-files '*.py' 2>/dev/null | grep -q . || ls ./*.py >/dev/null 2>&1 || exit 0
missing=()
for bin in ruff pyright pyright-langserver; do
  [[ -x ".venv/bin/$bin" ]] || command -v "$bin" >/dev/null || missing+=("$bin")
done
if (( ${#missing[@]} )); then
  list="$(IFS=,; echo "${missing[*]}")"
  echo "Jig python: missing tools: ${list//,/, }. Tell the user to run 'mise install' in this repo. Code intelligence and edit checks are degraded until then."
fi
