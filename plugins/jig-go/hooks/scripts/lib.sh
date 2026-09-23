#!/usr/bin/env bash
# Shared helpers for Jig Go hook scripts.

# Module root for a file: nearest ancestor with go.mod, not above the git root.
# Returns 1 (prints nothing) when the file is in no module: the go tool cannot
# build or test it then.
jig_go_root() {
  local dir top
  dir="$(cd "$(dirname -- "$1")" 2>/dev/null && pwd)" || return 1
  top="$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null)" || top=""
  local d="$dir"
  while :; do
    if [[ -f "$d/go.mod" ]]; then printf '%s\n' "$d"; return 0; fi
    [[ "$d" == "$top" || "$d" == / ]] && break
    d="$(dirname -- "$d")"
  done
  return 1
}

# Formatter command: goimports (formats and fixes imports), else gofmt (ships
# with go). Prints nothing and returns 1 when neither is on PATH.
jig_go_formatter() {
  command -v goimports 2>/dev/null || command -v gofmt 2>/dev/null
}

# Package pattern for a file inside a module root: "." or "./sub/dir".
jig_go_pkg() {
  local root="$1" dir
  dir="$(dirname -- "$2")"
  if [[ "$dir" == "$root" ]]; then printf '.\n'; else printf './%s\n' "${dir#"$root"/}"; fi
}

# Per-plugin state dir (survives plugin updates); temp dir outside Claude Code.
jig_go_state_dir() {
  local d="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/jig-go}"
  mkdir -p "$d" && printf '%s\n' "$d"
}

# File listing Go files edited in a session (one absolute path per line).
jig_go_session_file() {
  local sid="${1//[^A-Za-z0-9_-]/_}"
  printf '%s/sessions/%s.files\n' "$(jig_go_state_dir)" "${sid:-unknown}"
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
