#!/usr/bin/env bash
# Shared helpers for Jig Terraform hook scripts.

# Which binary this repo uses: $JIG_TF_BIN, else "tofu" when the repo signals
# OpenTofu (.opentofu-version, or opentofu in mise.toml), else "terraform",
# falling back to "tofu" when only that is installed. Prints nothing and
# returns 1 when the wanted binary is not on PATH.
jig_tf_bin() {
  local root want
  if [[ -n "${JIG_TF_BIN:-}" ]]; then
    command -v "$JIG_TF_BIN" >/dev/null || return 1
    printf '%s\n' "$JIG_TF_BIN"; return 0
  fi
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  if [[ -f "$root/.opentofu-version" ]] \
     || grep -qsE '^[[:space:]]*"?opentofu"?[[:space:]]*=' "$root/mise.toml" "$root/.mise.toml"; then
    want=tofu
  elif [[ -f "$root/.terraform-version" ]] || command -v terraform >/dev/null; then
    want=terraform
  else
    want=tofu
  fi
  command -v "$want" >/dev/null || return 1
  printf '%s\n' "$want"
}

# Per-plugin state dir (survives plugin updates); temp dir outside Claude Code.
jig_tf_state_dir() {
  local d="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/jig-terraform}"
  mkdir -p "$d" && printf '%s\n' "$d"
}

# File listing module dirs edited in a session (one absolute path per line).
jig_tf_session_file() {
  local sid="${1//[^A-Za-z0-9_-]/_}"
  printf '%s/sessions/%s.dirs\n' "$(jig_tf_state_dir)" "${sid:-unknown}"
}
