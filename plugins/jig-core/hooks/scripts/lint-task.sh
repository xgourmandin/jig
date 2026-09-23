#!/usr/bin/env bash
# Stop: when Claude edited repo files this session and the repo defines a mise
# `lint` task, run `mise run lint` once at the repo root, so the AI is held to
# exactly the CI standard. Stack plugins then skip their own static checks.
# Failures block the stop once; the re-check after Claude's fix only reports.
# No lint task: nothing to do (stack plugins call their tools directly).
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"

command -v jq >/dev/null || exit 0
sid="$(jq -r '.session_id // empty' <<<"$input")"
state="$(jig_session_file "$sid")"
[[ -s "$state" ]] || exit 0
# Loop protection: never block twice in a row. When a Stop hook already blocked
# in this stop cycle, still re-check Claude's fix, but only report failures.
recheck="$(jq -r '.stop_hook_active // false' <<<"$input")"

root="$(cd "$(dirname -- "$(head -1 "$state")")" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" \
  || root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
if ! jig_lint_task "$root"; then rm -f "$state"; exit 0; fi
cd "$root" || exit 0

# Never install tools from a hook: missing ones are a setup problem.
out="$(MISE_TASK_RUN_AUTO_INSTALL=false mise run lint 2>&1)"; rc=$?
if (( rc == 0 )); then rm -f "$state"; exit 0; fi
if grep -qiE 'not trusted|untrusted' <<<"$out"; then
  jq -n '{systemMessage: "Jig: skipped the repo lint task: mise config is not trusted. Run `mise trust` in this repo."}'
  exit 0
fi

msg="$(tail -60 <<<"$out")"
if [[ "$recheck" == true ]]; then
  # Keep the list: the next stop checks again.
  jq -n --arg m "Jig: \`mise run lint\` still fails after Claude's fix (not blocking twice):"$'\n\n'"$msg" '{systemMessage: $m}'
  exit 0
fi
jq -n --arg r "The repo's lint task (\`mise run lint\`, the same check CI runs) failed after your changes (exit $rc). Fix what your changes caused, then stop. If a failure predates this session and is unrelated to your work, don't fix it: tell the user."$'\n\n'"$msg" \
  '{decision: "block", reason: $r}'
exit 0
