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

# Does the repo at $1 define a mise `lint` task ([tasks.lint], or `lint =` under
# [tasks], in a mise config file, or a file task), with mise installed? Then the
# repo's lint task (run by jig-core on Stop, same as CI) replaces the direct
# static checks. Keep this function identical in every Jig plugin's lib.sh.
jig_lint_task() {
  local root="$1" f
  command -v mise >/dev/null || return 1
  for f in lint lint.sh; do
    for d in mise-tasks .mise-tasks mise/tasks .mise/tasks .config/mise/tasks; do
      [[ -f "$root/$d/$f" ]] && return 0
    done
  done
  for f in mise.toml .mise.toml mise/config.toml .mise/config.toml .config/mise.toml .config/mise/config.toml; do
    [[ -f "$root/$f" ]] || continue
    awk '
      /^[[:space:]]*\[/ { sec = $0; gsub(/[[:space:]"]/, "", sec); if (sec == "[tasks.lint]") { found = 1; exit } next }
      sec == "[tasks]" && /^[[:space:]]*"?lint"?[[:space:]]*=/ { found = 1; exit }
      END { exit !found }
    ' "$root/$f" && return 0
  done
  return 1
}
