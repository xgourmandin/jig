#!/usr/bin/env bash
# PostToolUse: after Claude edits a .py/.pyi file, format it and apply safe lint
# fixes with ruff (the repo's ruff config applies). Remaining problems are fed
# back to Claude with exit 2. Also records the file for the Stop checks.
# Type errors come from the pyright LSP after each edit, so none here.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[[ "$file" =~ \.pyi?$ ]] || exit 0
[[ -f "$file" ]] || exit 0
file="$(cd "$(dirname -- "$file")" && pwd)/$(basename -- "$file")"

# 0. Remember this file for the Stop checks (see py-stop-check.sh).
sid="$(jq -r '.session_id // empty' <<<"$input")"
state="$(jig_py_session_file "$sid")"
mkdir -p "$(dirname "$state")"
grep -qxF "$file" "$state" 2>/dev/null || printf '%s\n' "$file" >>"$state"

root="$(jig_py_root "$file")"
ruff="$(jig_py_tool "$root" ruff)" || exit 0
cd "$root" || exit 0
# Keep ruff's cache out of the repo.
export RUFF_CACHE_DIR="${RUFF_CACHE_DIR:-$(jig_py_state_dir)/ruff-cache}"
problems=""

# 1. ruff format: fixes formatting in place; fails on syntax errors.
if ! out="$("$ruff" format --force-exclude --quiet "$file" 2>&1)"; then
  problems+=$'ruff format failed (likely a syntax error):\n'"$out"$'\n'
# 2. ruff check with safe fixes; report what is left.
elif ! out="$("$ruff" check --force-exclude --fix --quiet --output-format concise "$file" 2>&1)"; then
  problems+=$'ruff check reported issues:\n'"$out"$'\n'
fi

if [[ -n "$problems" ]]; then
  printf 'Jig python checks for %s:\n%s' "$file" "$problems" >&2
  exit 2
fi
exit 0
