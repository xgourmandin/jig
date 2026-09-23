#!/usr/bin/env bash
# PostToolUse: after Claude edits a .go file, format it and fix its imports with
# goimports (gofmt when goimports is missing). Syntax errors are fed back to
# Claude with exit 2. Also records the file for the Stop checks.
# Compile and vet errors come from the gopls LSP after each edit, and
# golangci-lint runs on Stop: it loads and type-checks whole packages, which is
# too slow to run after every edit in a real repo.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[[ "$file" == *.go ]] || exit 0
[[ -f "$file" ]] || exit 0
file="$(cd "$(dirname -- "$file")" && pwd)/$(basename -- "$file")"

# 0. Remember this file for the Stop checks (see go-stop-check.sh).
sid="$(jq -r '.session_id // empty' <<<"$input")"
state="$(jig_go_session_file "$sid")"
mkdir -p "$(dirname "$state")"
grep -qxF "$file" "$state" 2>/dev/null || printf '%s\n' "$file" >>"$state"

fmt="$(jig_go_formatter)" || exit 0
# goimports resolves missing imports from the module, so run it from there.
cd "$(jig_go_root "$file" || dirname -- "$file")" || exit 0

# 1. Format in place; fails (and changes nothing) on syntax errors.
if ! out="$("$fmt" -w "$file" 2>&1)"; then
  printf 'Jig go checks for %s:\n%s failed (likely a syntax error):\n%s\n' \
    "$file" "$(basename -- "$fmt")" "$(head -20 <<<"$out")" >&2
  exit 2
fi
exit 0
