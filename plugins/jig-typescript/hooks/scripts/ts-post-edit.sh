#!/usr/bin/env bash
# PostToolUse: after Claude edits a TS/JS file, format it and apply safe lint
# fixes with the tool the repo uses (its config and ignore files apply):
#   biome.json          -> biome check --write
#   eslint config       -> prettier --write (if the repo uses prettier), eslint --fix
#   prettier config only -> prettier --write
# Remaining errors are fed back to Claude with exit 2. Also records the file
# for the Stop checks. Type errors come from the TypeScript LSP after each
# edit, so none here.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"
file="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
[[ "$file" =~ $JIG_TS_EXT_RE ]] || exit 0
[[ -f "$file" ]] || exit 0
file="$(cd "$(dirname -- "$file")" && pwd)/$(basename -- "$file")"

# 0. Remember this file for the Stop checks (see ts-stop-check.sh).
sid="$(jq -r '.session_id // empty' <<<"$input")"
state="$(jig_ts_session_file "$sid")"
mkdir -p "$(dirname "$state")"
grep -qxF "$file" "$state" 2>/dev/null || printf '%s\n' "$file" >>"$state"

root="$(jig_ts_root "$file")"
cd "$root" || exit 0
linter="$(jig_ts_linter "$root")"
problems="" notes=""

if [[ "$linter" == biome ]]; then
  # 1. biome: format + safe fixes; errors (not warnings) fail, like in CI.
  if biome="$(jig_ts_tool "$root" biome)"; then
    if ! out="$("$biome" check --write --no-errors-on-unmatched --files-ignore-unknown=true \
                  --colors=off --reporter=concise --diagnostic-level=error "$file" 2>&1)"; then
      found="$(grep -E '^[^[:space:]]+ [^[:space:]]+: ' <<<"$out" | head -30)"
      if [[ -n "$found" ]]; then problems+=$'biome check reported errors:\n'"$found"$'\n'
      else notes+="biome could not check $file: $(head -5 <<<"$out") "; fi
    fi
  fi
else
  # 1. prettier: formats in place (repo config, .prettierignore); fails on
  # syntax errors.
  if jig_ts_uses_prettier "$root"; then
    if prettier="$(jig_ts_tool "$root" prettier)"; then
      if ! out="$("$prettier" --write --ignore-unknown --log-level warn "$file" 2>&1)"; then
        problems+=$'prettier failed (likely a syntax error):\n'"$(head -20 <<<"$out")"$'\n'
      fi
    fi
  fi
  # 2. eslint with safe fixes; report the errors that are left (exit 1).
  # Exit 2 means eslint itself failed (config, plugins): tell the user.
  if [[ "$linter" == eslint && -z "$problems" ]]; then
    if eslint="$(jig_ts_tool "$root" eslint)"; then
      out="$("$eslint" --fix --no-warn-ignored --format json "$file" 2>/dev/null)"; rc=$?
      if (( rc == 1 )); then
        found="$(jq -r --arg r "$root/" '.[] | (.filePath | ltrimstr($r)) as $f | .messages[]
                   | select(.severity == 2)
                   | "\($f):\(.line):\(.column) \(.ruleId // "error") \(.message)"' <<<"$out" 2>/dev/null | head -30)"
        problems+=$'eslint reported errors:\n'"$found"$'\n'
      elif (( rc != 0 )); then
        notes+="eslint could not run on $file (exit $rc; check the eslint config and 'npm install'). "
      fi
    fi
  fi
fi

if [[ -n "$problems" ]]; then
  printf 'Jig typescript checks for %s:\n%s' "$file" "$problems" >&2
  exit 2
fi
# Tool failures never block the edit; the user sees them. Missing tools are
# reported once per session by check-tools.sh instead.
[[ -n "$notes" ]] && jq -n --arg m "Jig typescript: $notes" '{systemMessage: $m}'
exit 0
