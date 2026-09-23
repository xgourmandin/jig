#!/usr/bin/env bash
# Stop: for every Python project Claude edited in this session (files recorded
# by py-post-edit.sh), type check the edited files with pyright and run the
# project's pytest suite. Failures block the stop once; the re-check after
# Claude's fix only reports. Missing tools only warn.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"

command -v jq >/dev/null || exit 0
sid="$(jq -r '.session_id // empty' <<<"$input")"
state="$(jig_py_session_file "$sid")"
[[ -s "$state" ]] || exit 0
# Loop protection: never block twice in a row. When a Stop hook already blocked
# in this stop cycle, still re-check Claude's fix, but only report failures.
recheck="$(jq -r '.stop_hook_active // false' <<<"$input")"

errors="" warnings=""
declare -A files_by_root=()
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  root="$(jig_py_root "$f")"
  files_by_root["$root"]+="$f"$'\n'
done < <(sort -u "$state")

for root in "${!files_by_root[@]}"; do
  mapfile -t files <<<"${files_by_root[$root]%$'\n'}"
  cd "$root" || continue

  # 1. pyright on the edited files, with the project's config and venv.
  if pyright="$(jig_py_tool "$root" pyright)"; then
    args=(--outputjson)
    [[ -x "$root/.venv/bin/python" ]] && args+=(--pythonpath "$root/.venv/bin/python")
    out="$("$pyright" "${args[@]}" "${files[@]}" 2>/dev/null \
      | jq -r '.generalDiagnostics[]? | select(.severity == "error")
               | "\(.file):\(.range.start.line + 1) \(.message | split("\n")[0])"' 2>/dev/null)"
    [[ -n "$out" ]] && errors+="## $root (pyright)"$'\n'"$(head -40 <<<"$out")"$'\n\n'
  else
    warnings+="pyright not found in $root. "
  fi

  # 2. pytest (exit 5 = no tests collected, fine). No cache or bytecode files
  # left in the repo.
  if mapfile -t pytest < <(jig_py_pytest "$root") && (( ${#pytest[@]} )); then
    out="$(PYTHONDONTWRITEBYTECODE=1 "${pytest[@]}" -q -x --no-header -p no:cacheprovider 2>&1)"; rc=$?
    if (( rc != 0 && rc != 5 )); then
      errors+="## $root (pytest, exit $rc)"$'\n'"$(tail -40 <<<"$out")"$'\n\n'
    fi
  else
    warnings+="pytest not found in $root. "
  fi
done

if [[ -n "$errors" ]]; then
  if [[ "$recheck" == true ]]; then
    # Keep the list: the next stop checks again.
    jq -n --arg m "Jig python: checks still fail after Claude's fix (not blocking twice):"$'\n\n'"$errors$warnings" \
      '{systemMessage: $m}'
    exit 0
  fi
  jq -n --arg r "Checks failed for Python code edited in this session. Fix them, then stop. Do not weaken or skip tests or add type: ignore unless the user agrees:"$'\n\n'"$errors$warnings" \
    '{decision: "block", reason: $r}'
  exit 0
fi
rm -f "$state"
[[ -n "$warnings" ]] && jq -n --arg m "Jig python: ${warnings}Run 'mise install' (or 'uv sync')." '{systemMessage: $m}'
exit 0
