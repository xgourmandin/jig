#!/usr/bin/env bash
# Stop: for the TS/JS code Claude edited in this session (files recorded by
# ts-post-edit.sh), type check each TypeScript project (nearest tsconfig.json)
# with `tsc --noEmit`, then run each package's tests (nearest package.json):
# vitest, else the package manager's `test` script. Never installs packages.
# Failures block the stop once; the re-check after Claude's fix only reports.
# Missing tools only warn.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"

command -v jq >/dev/null || exit 0
sid="$(jq -r '.session_id // empty' <<<"$input")"
state="$(jig_ts_session_file "$sid")"
[[ -s "$state" ]] || exit 0
# Loop protection: never block twice in a row. When a Stop hook already blocked
# in this stop cycle, still re-check Claude's fix, but only report failures.
recheck="$(jq -r '.stop_hook_active // false' <<<"$input")"

errors="" warnings=""
declare -A roots=() tsconfigs=()
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  root="$(jig_ts_root "$f")"
  roots["$root"]=1
  if tsconfig="$(jig_ts_find_up "$(dirname -- "$f")" tsconfig.json)"; then
    tsconfigs["$tsconfig"]="$root"
  fi
done < <(sort -u "$state")

# 1. tsc on each edited TypeScript project: whole project, errors only. The
# build info file (incremental/composite projects) goes to the plugin data dir.
for tsconfig in "${!tsconfigs[@]}"; do
  dir="$(dirname -- "$tsconfig")"
  if tsc="$(jig_ts_tool "${tsconfigs[$tsconfig]}" tsc)"; then
    key="$(printf '%s' "$tsconfig" | cksum | cut -d' ' -f1)"
    mkdir -p "$(jig_ts_state_dir)/tsbuildinfo"
    out="$(cd "$dir" && "$tsc" --noEmit --pretty false -p tsconfig.json \
      --tsBuildInfoFile "$(jig_ts_state_dir)/tsbuildinfo/$key.tsbuildinfo" 2>&1)"; rc=$?
    if (( rc != 0 )); then
      found="$(grep -E 'error TS[0-9]+' <<<"$out")"
      errors+="## $dir (tsc)"$'\n'"$(head -40 <<<"${found:-$out}")"$'\n\n'
    fi
  else
    warnings+="tsc not found in $dir. "
  fi
done

# 2. Tests per package. CI=true keeps runners out of watch mode.
for root in "${!roots[@]}"; do
  [[ -f "$root/package.json" ]] || continue
  words="$(jig_ts_test_cmd "$root")"; rc=$?
  mapfile -t cmd <<<"$words"
  case "$rc" in
    1) continue ;;
    2) warnings+="test runner not found in $root. "; continue ;;
  esac
  name="$(basename -- "${cmd[0]}")"; [[ "$name" == vitest ]] || name="${cmd[*]}"
  out="$(cd "$root" && CI=true "${cmd[@]}" 2>&1)"; rc=$?
  if (( rc != 0 )); then
    errors+="## $root ($name, exit $rc)"$'\n'"$(tail -40 <<<"$out")"$'\n\n'
  fi
done

if [[ -n "$errors" ]]; then
  if [[ "$recheck" == true ]]; then
    # Keep the list: the next stop checks again.
    jq -n --arg m "Jig typescript: checks still fail after Claude's fix (not blocking twice):"$'\n\n'"$errors$warnings" \
      '{systemMessage: $m}'
    exit 0
  fi
  jq -n --arg r "Checks failed for TypeScript/JavaScript code edited in this session. Fix them, then stop. Do not weaken or skip tests or add @ts-ignore/@ts-expect-error or eslint-disable unless the user agrees:"$'\n\n'"$errors$warnings" \
    '{decision: "block", reason: $r}'
  exit 0
fi
rm -f "$state"
[[ -n "$warnings" ]] && jq -n --arg m "Jig typescript: ${warnings}Run 'mise install' (or the repo's package install)." '{systemMessage: $m}'
exit 0
