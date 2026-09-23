#!/usr/bin/env bash
# Stop: validate every Terraform/OpenTofu module Claude edited in this session
# (dirs recorded by tf-post-edit.sh). Offline: `init -backend=false`, no
# credentials, no plan. Never leaves files in the repo: .terraform goes to the
# plugin data dir and the lock file is restored afterwards.
# Then scans them with trivy (offline, HIGH/CRITICAL) when installed.
# Findings block the stop once; tool/init problems only warn the user.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
input="$(cat)"

command -v jq >/dev/null || exit 0
sid="$(jq -r '.session_id // empty' <<<"$input")"
state="$(jig_tf_session_file "$sid")"
[[ -s "$state" ]] || exit 0
# Loop protection: we already blocked in this stop cycle; keep the list so the
# next stop re-checks the fix.
[[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]] && exit 0

warn() { jq -n --arg m "Jig terraform: $1" '{systemMessage: $m}'; exit 0; }

first_dir="$(head -1 "$state")"
tf="$(cd "$first_dir" 2>/dev/null && jig_tf_bin)" || warn "terraform/tofu not found, skipped validation. Run 'mise install'."

data_root="$(jig_tf_state_dir)"
export TF_IN_AUTOMATION=1
export TF_PLUGIN_CACHE_DIR="${TF_PLUGIN_CACHE_DIR:-$data_root/plugin-cache}"
mkdir -p "$TF_PLUGIN_CACHE_DIR"

errors="" warnings=""
while IFS= read -r dir; do
  [[ -d "$dir" ]] || continue
  compgen -G "$dir/*.tf" >/dev/null || continue
  key="$(printf '%s' "$dir" | cksum | cut -d' ' -f1)"
  export TF_DATA_DIR="$data_root/tfdata/$key"
  lock="$dir/.terraform.lock.hcl" saved=""
  if [[ -f "$lock" ]]; then saved="$(mktemp)"; cp -p "$lock" "$saved"; fi

  if out="$("$tf" -chdir="$dir" init -backend=false -input=false -no-color 2>&1)"; then
    if ! out="$("$tf" -chdir="$dir" validate -no-color 2>&1)"; then
      errors+="## $dir ($tf validate)"$'\n'"$(head -60 <<<"$out")"$'\n\n'
    elif command -v trivy >/dev/null; then
      # Offline misconfiguration scan (embedded checks bundle, no download).
      out="$(trivy config --quiet --skip-check-update --severity HIGH,CRITICAL --format json "$dir" 2>/dev/null \
        | jq -r '.Results[]? | .Target as $t | .Misconfigurations[]?
                 | "\($t):\(.CauseMetadata.StartLine) \(.ID) \(.Severity): \(.Title)"' 2>/dev/null)"
      [[ -n "$out" ]] && errors+="## $dir (trivy config)"$'\n'"$(head -40 <<<"$out")"$'\n\n'
    fi
  else
    warnings+="init failed in $dir: $(grep -m1 -i 'error' <<<"$out")"$'\n'
  fi

  if [[ -n "$saved" ]]; then mv -f "$saved" "$lock"; else rm -f "$lock"; fi
done < <(sort -u "$state")

if [[ -n "$errors" ]]; then
  jq -n --arg r "Checks failed for Terraform modules edited in this session. Fix them, then stop. For a trivy finding that is intended, add \`#trivy:ignore:<ID>\` with a reason, but only if the user agrees:"$'\n\n'"$errors$warnings" \
    '{decision: "block", reason: $r}'
  exit 0
fi
rm -f "$state"
[[ -n "$warnings" ]] && warn "validation skipped, $warnings"
exit 0
