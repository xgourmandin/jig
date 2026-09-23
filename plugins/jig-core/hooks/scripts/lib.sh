#!/usr/bin/env bash
# Shared helpers for Jig hook scripts.

# Work-state folder for the current branch: <repo>/.ai/work/<branch, "/" -> "-">
jig_work_dir() {
  local root branch
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 1
  printf '%s/.ai/work/%s\n' "$root" "${branch//\//-}"
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

# Per-plugin state dir (survives plugin updates); temp dir outside Claude Code.
jig_state_dir() {
  local d="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/jig-core}"
  mkdir -p "$d" && printf '%s\n' "$d"
}

# File listing repo files edited in a session (one absolute path per line).
jig_session_file() {
  local sid="${1//[^A-Za-z0-9_-]/_}"
  printf '%s/sessions/%s.files\n' "$(jig_state_dir)" "${sid:-unknown}"
}
