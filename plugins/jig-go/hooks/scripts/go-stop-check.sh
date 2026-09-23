#!/usr/bin/env bash
# Stop: for every Go module Claude edited in this session (files recorded by
# go-post-edit.sh), lint the edited packages with golangci-lint (the repo's
# .golangci.yml applies; `go vet` when golangci-lint is missing) and run their
# tests. Failures block the stop once; the re-check after Claude's fix only
# reports. Missing tools only warn.
# Never changes go.mod/go.sum (-mod=readonly) and writes no files in the repo:
# build, test and lint caches live outside it.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"

command -v jq >/dev/null || exit 0
sid="$(jq -r '.session_id // empty' <<<"$input")"
state="$(jig_go_session_file "$sid")"
[[ -s "$state" ]] || exit 0
# Loop protection: never block twice in a row. When a Stop hook already blocked
# in this stop cycle, still re-check Claude's fix, but only report failures.
recheck="$(jq -r '.stop_hook_active // false' <<<"$input")"

errors="" warnings=""
declare -A pkgs_by_root=()
while IFS= read -r f; do
  [[ -f "$f" ]] || continue
  root="$(jig_go_root "$f")" || continue
  pkg="$(jig_go_pkg "$root" "$f")"
  [[ $'\n'"${pkgs_by_root[$root]:-}" == *$'\n'"$pkg"$'\n'* ]] || pkgs_by_root["$root"]+="$pkg"$'\n'
done < <(sort -u "$state")

# Keep golangci-lint's cache out of the repo (go's own caches already are).
export GOLANGCI_LINT_CACHE="${GOLANGCI_LINT_CACHE:-$(jig_go_state_dir)/golangci-lint-cache}"

for root in "${!pkgs_by_root[@]}"; do
  mapfile -t pkgs <<<"${pkgs_by_root[$root]%$'\n'}"
  cd "$root" || continue
  if ! command -v go >/dev/null; then warnings+="go not found for $root. "; continue; fi
  # Use the vendor dir when there is one; otherwise never touch go.mod/go.sum.
  # Command-line flags win over GOFLAGS (e.g. a user's -mod=mod).
  mod="readonly"; [[ -f vendor/modules.txt ]] && mod="vendor"

  # 1. golangci-lint on the edited packages (exit 1 = issues, incl. compile
  # errors as "typecheck"). A config it cannot load is the repo's problem, not
  # this session's: warn. Without golangci-lint, fall back to go vet.
  if command -v golangci-lint >/dev/null; then
    out="$(golangci-lint run --modules-download-mode="$mod" --allow-serial-runners --timeout=5m --show-stats=false \
      --output.text.path=stdout --output.text.colors=false --output.text.print-issued-lines=false \
      "${pkgs[@]}" 2>&1)"; rc=$?
    if (( rc != 0 )) && grep -q "can't load config" <<<"$out"; then
      warnings+="golangci-lint could not load the config in $root ($(grep -m1 "can't load config" <<<"$out" | sed 's/^Error: //')). "
    elif (( rc != 0 )); then
      errors+="## $root (golangci-lint, exit $rc)"$'\n'"$(head -40 <<<"$out")"$'\n\n'
    fi
  else
    warnings+="golangci-lint not found for $root (ran go vet instead). "
    out="$(go vet -mod="$mod" "${pkgs[@]}" 2>&1)" \
      || errors+="## $root (go vet)"$'\n'"$(head -40 <<<"$out")"$'\n\n'
  fi

  # 2. go test on the edited packages (cached results are reused).
  out="$(go test -mod="$mod" -timeout=5m "${pkgs[@]}" 2>&1)"; rc=$?
  if (( rc != 0 )); then
    errors+="## $root (go test, exit $rc)"$'\n'"$(grep -v '^ok ' <<<"$out" | tail -40)"$'\n\n'
  fi
done

if [[ -n "$errors" ]]; then
  if [[ "$recheck" == true ]]; then
    # Keep the list: the next stop checks again.
    jq -n --arg m "Jig go: checks still fail after Claude's fix (not blocking twice):"$'\n\n'"$errors$warnings" \
      '{systemMessage: $m}'
    exit 0
  fi
  jq -n --arg r "Checks failed for Go code edited in this session. Fix them, then stop. Do not weaken or skip tests or add //nolint unless the user agrees:"$'\n\n'"$errors$warnings" \
    '{decision: "block", reason: $r}'
  exit 0
fi
rm -f "$state"
[[ -n "$warnings" ]] && jq -n --arg m "Jig go: ${warnings}Run 'mise install'." '{systemMessage: $m}'
exit 0
