#!/usr/bin/env bash
# Stop hook: if this branch has a work folder and code changed but neither
# plan.md nor progress.md was touched, ask Claude (once) to log progress.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"

# Loop protection: if we already blocked in this stop cycle, let Claude stop.
[[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]] && exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

dir="$(acme_work_dir)"
[[ -d "$dir" ]] || exit 0
root="$(git rev-parse --show-toplevel)"
rel="${dir#"$root"/}"
cd "$root" || exit 0

changed_code="$(git status --porcelain | cut -c4- | grep -v '^\.ai/' | head -1)"
changed_state="$(git status --porcelain -- "$rel/progress.md" "$rel/plan.md")"

if [[ -n "$changed_code" && -z "$changed_state" ]]; then
  jq -n --arg r "Code changed but $rel/plan.md and progress.md were not updated. Tick finished tasks in plan.md and append a dated entry to progress.md (Done / Decisions / Next / Blockers), then stop." \
    '{decision: "block", reason: $r}'
fi
exit 0
