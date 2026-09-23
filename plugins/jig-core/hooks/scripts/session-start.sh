#!/usr/bin/env bash
# SessionStart: stdout is added to Claude's context.
# Tells Claude where the work stands on this branch. Also fires after
# compaction (source "compact"); then the current plan phase is re-injected,
# because the compaction summary may have dropped it. (PreCompact output does
# not reach Claude, so this is the documented place to restore context.)
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

input="$(cat 2>/dev/null || true)"
source_kind=""
if command -v jq >/dev/null; then
  source_kind="$(jq -r '.source // empty' <<<"$input" 2>/dev/null || true)"
fi

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
    if [[ "$source_kind" == "compact" ]]; then
      # The "## " section of plan.md that holds the first open task.
      phase="$(awk '/^## /{ if (found) exit; sec=$0 "\n"; next }
                    { sec=sec $0 "\n" }
                    /^[[:space:]]*- \[ \]/{ found=1 }
                    END{ if (found) printf "%s", sec }' "$dir/plan.md")"
      if [[ -n "$phase" ]]; then
        echo
        echo "Context was just compacted. Current plan phase (from $rel/plan.md):"
        printf '%s\n' "$phase"
      fi
    fi
  fi
  if [[ -f "$dir/progress.md" ]]; then
    echo
    echo "Last progress entry:"
    awk '/^## /{buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' "$dir/progress.md"
  fi
  echo
  to_read=()
  for f in spec.md plan.md; do
    [[ -f "$dir/$f" ]] && to_read+=("$rel/$f")
  done
  if (( ${#to_read[@]} )); then
    list="${to_read[0]}"
    (( ${#to_read[@]} > 1 )) && list+=" and ${to_read[1]}"
    echo "Read $list before starting. Keep progress.md up to date."
  else
    echo "Keep $rel/progress.md up to date."
  fi
else
  echo "No work state for this branch ($rel). For multi-session work, use the start-work skill."
fi
