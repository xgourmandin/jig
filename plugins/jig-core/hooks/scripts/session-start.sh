#!/usr/bin/env bash
# SessionStart: stdout is added to Claude's context.
# Tells Claude where the work stands on this branch.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
root="$(git rev-parse --show-toplevel)"
branch="$(git rev-parse --abbrev-ref HEAD)"
dir="$(jig_work_dir)"
rel="${dir#"$root"/}"

echo "## Jig harness: session context"
echo "Branch: $branch"

if [[ -d "$dir" ]]; then
  echo "Work state folder: $rel"
  if [[ -f "$dir/plan.md" ]]; then
    done_n=$(grep -cE '^[[:space:]]*- \[[xX]\]' "$dir/plan.md" || true)
    todo_n=$(grep -cE '^[[:space:]]*- \[ \]' "$dir/plan.md" || true)
    echo "Plan: $done_n done, $todo_n open."
    next="$(grep -m1 -E '^[[:space:]]*- \[ \]' "$dir/plan.md" | sed -E 's/^[[:space:]]*- \[ \] //')"
    [[ -n "$next" ]] && echo "Next open task: $next"
  fi
  if [[ -f "$dir/progress.md" ]]; then
    echo
    echo "Last progress entry:"
    awk '/^## /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$dir/progress.md"
  fi
  echo
  echo "Read $rel/spec.md and $rel/plan.md before starting. Keep progress.md up to date."
else
  echo "No work state for this branch ($rel). For multi-session work, use the start-work skill."
fi
