#!/usr/bin/env bash
# PostToolUse: remember which repo files Claude edited in this session, so the
# Stop hook (lint-task.sh) runs the repo's lint task only when code changed.
# Work state under .ai/ does not count.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[[ -n "$file" && -f "$file" ]] || exit 0
file="$(cd "$(dirname -- "$file")" && pwd)/$(basename -- "$file")"
root="$(cd "$(dirname -- "$file")" && git rev-parse --show-toplevel 2>/dev/null)" || exit 0
[[ "$file" == "$root/.ai/"* ]] && exit 0

sid="$(jq -r '.session_id // empty' <<<"$input")"
state="$(jig_session_file "$sid")"
mkdir -p "$(dirname "$state")"
grep -qxF "$file" "$state" 2>/dev/null || printf '%s\n' "$file" >>"$state"
exit 0
