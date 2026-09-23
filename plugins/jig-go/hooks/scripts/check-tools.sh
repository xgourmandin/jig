#!/usr/bin/env bash
# SessionStart: warn (in Claude's context) when required binaries are missing,
# so Claude tells the user instead of silently degrading.
set -uo pipefail
git ls-files '*.go' '*go.mod' 2>/dev/null | grep -q . || [[ -f go.mod ]] || compgen -G './*.go' >/dev/null || exit 0
missing=()
for bin in go gopls goimports golangci-lint; do
  command -v "$bin" >/dev/null || missing+=("$bin")
done
if (( ${#missing[@]} )); then
  list="$(IFS=,; echo "${missing[*]}")"
  echo "Jig go: missing tools: ${list//,/, }. Tell the user to run 'mise install' in this repo. Code intelligence and edit checks are degraded until then."
fi
