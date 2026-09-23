#!/usr/bin/env bash
# Shared helpers for Jig Python hook scripts.

# Project root for a file: nearest ancestor with pyproject.toml, setup.cfg or
# setup.py, not above the git root; else the git root; else the file's dir.
jig_py_root() {
  local dir top
  dir="$(cd "$(dirname -- "$1")" 2>/dev/null && pwd)" || return 1
  top="$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null)" || top=""
  local d="$dir"
  while :; do
    if [[ -f "$d/pyproject.toml" || -f "$d/setup.cfg" || -f "$d/setup.py" ]]; then
      printf '%s\n' "$d"; return 0
    fi
    [[ "$d" == "$top" || "$d" == / ]] && break
    d="$(dirname -- "$d")"
  done
  printf '%s\n' "${top:-$dir}"
}

# Command for a tool in a project: the project's .venv first (its pinned
# version), else PATH (mise). Prints nothing and returns 1 when neither exists.
jig_py_tool() {
  local root="$1" name="$2"
  if [[ -x "$root/.venv/bin/$name" ]]; then printf '%s\n' "$root/.venv/bin/$name"; return 0; fi
  command -v "$name" 2>/dev/null
}

# pytest command for a project, one word per line: `uv run --frozen pytest`
# when the project is managed by uv (uv.lock), else the tool lookup above.
jig_py_pytest() {
  local root="$1" bin
  if [[ -f "$root/uv.lock" ]] && command -v uv >/dev/null; then
    printf '%s\n' uv run --frozen pytest; return 0
  fi
  bin="$(jig_py_tool "$root" pytest)" || return 1
  printf '%s\n' "$bin"
}

# Per-plugin state dir (survives plugin updates); temp dir outside Claude Code.
jig_py_state_dir() {
  local d="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/jig-python}"
  mkdir -p "$d" && printf '%s\n' "$d"
}

# File listing Python files edited in a session (one absolute path per line).
jig_py_session_file() {
  local sid="${1//[^A-Za-z0-9_-]/_}"
  printf '%s/sessions/%s.files\n' "$(jig_py_state_dir)" "${sid:-unknown}"
}
