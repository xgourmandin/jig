#!/usr/bin/env bash
# Shared helpers for Jig TypeScript hook scripts.

# TS/JS source files the hooks handle.
# shellcheck disable=SC2034 # used by ts-post-edit.sh
JIG_TS_EXT_RE='\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$'

# Directories from $1 up to the git root (or / outside git), one per line.
jig_ts_up() {
  local d top
  d="$(cd "$1" 2>/dev/null && pwd)" || return 1
  top="$(cd "$d" && git rev-parse --show-toplevel 2>/dev/null)" || top=""
  while :; do
    printf '%s\n' "$d"
    [[ "$d" == "$top" || "$d" == / ]] && break
    d="$(dirname -- "$d")"
  done
}

# First existing path named $2, $3... in $1 or its ancestors (not above git root).
jig_ts_find_up() {
  local start="$1" d n; shift
  while IFS= read -r d; do
    for n in "$@"; do
      [[ -e "$d/$n" ]] && { printf '%s\n' "$d/$n"; return 0; }
    done
  done < <(jig_ts_up "$start")
  return 1
}

# Project root for a file: nearest ancestor with package.json, not above the
# git root; else the git root; else the file's dir.
jig_ts_root() {
  local dir top pkg
  dir="$(cd "$(dirname -- "$1")" 2>/dev/null && pwd)" || return 1
  if pkg="$(jig_ts_find_up "$dir" package.json)"; then dirname -- "$pkg"; return 0; fi
  top="$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null)" || top=""
  printf '%s\n' "${top:-$dir}"
}

# Command for a tool in a project: node_modules/.bin in the project or an
# ancestor (monorepos hoist it; the version the project pins), else PATH
# (mise). Prints nothing and returns 1 when neither exists.
jig_ts_tool() {
  local root="$1" name="$2" d
  while IFS= read -r d; do
    [[ -x "$d/node_modules/.bin/$name" ]] && { printf '%s\n' "$d/node_modules/.bin/$name"; return 0; }
  done < <(jig_ts_up "$root")
  command -v "$name" 2>/dev/null
}

# True when a package.json in the project (or an ancestor) has top-level key
# $2 or depends on package $2.
jig_ts_pkg_has() {
  local root="$1" key="$2" d
  while IFS= read -r d; do
    [[ -f "$d/package.json" ]] || continue
    jq -e --arg k "$key" 'has($k) or ((.dependencies // {}) + (.devDependencies // {}) | has($k))' \
      "$d/package.json" >/dev/null 2>&1 && return 0
  done < <(jig_ts_up "$root")
  return 1
}

# Which formatter/linter the repo uses, from its config files (nearest wins):
# biome (biome.json[c]) | eslint (eslint.config.*, .eslintrc*, eslintConfig in
# package.json) | none.
jig_ts_linter() {
  local d f
  while IFS= read -r d; do
    [[ -f "$d/biome.json" || -f "$d/biome.jsonc" ]] && { echo biome; return 0; }
    for f in "$d"/eslint.config.{js,mjs,cjs,ts,mts,cts} "$d"/.eslintrc{,.js,.cjs,.json,.yaml,.yml}; do
      [[ -f "$f" ]] && { echo eslint; return 0; }
    done
    [[ -f "$d/package.json" ]] && jq -e 'has("eslintConfig")' "$d/package.json" >/dev/null 2>&1 \
      && { echo eslint; return 0; }
  done < <(jig_ts_up "$1")
  echo none
}

# True when the repo uses prettier: a prettier config file, a "prettier" key or
# a prettier dependency in package.json. We never impose prettier's style on a
# repo that does not use it.
jig_ts_uses_prettier() {
  local root="$1" d f
  while IFS= read -r d; do
    for f in "$d"/.prettierrc{,.json,.json5,.yaml,.yml,.toml,.js,.cjs,.mjs,.ts,.mts,.cts} \
             "$d"/prettier.config.{js,cjs,mjs,ts,mts,cts}; do
      [[ -f "$f" ]] && return 0
    done
  done < <(jig_ts_up "$root")
  jig_ts_pkg_has "$root" prettier
}

# Package manager of a project, from the nearest lockfile, else the
# packageManager field, else npm.
jig_ts_pm() {
  local root="$1" lock pm
  if lock="$(jig_ts_find_up "$root" pnpm-lock.yaml yarn.lock bun.lock bun.lockb package-lock.json)"; then
    case "$(basename -- "$lock")" in
      pnpm-lock.yaml) echo pnpm ;; yarn.lock) echo yarn ;; bun.lock*) echo bun ;; *) echo npm ;;
    esac
    return 0
  fi
  pm="$(jq -r '.packageManager // empty' "$root/package.json" 2>/dev/null)"
  case "$pm" in pnpm@*) echo pnpm ;; yarn@*) echo yarn ;; bun@*) echo bun ;; *) echo npm ;; esac
}

# Test command for a project, one word per line:
# - vitest (`vitest run`) when the project uses it (dependency, config file or
#   installed in node_modules/.bin); cache off so nothing is written;
# - else `<pm> test` when package.json has a real scripts.test (not npm's
#   "no test specified" stub);
# Returns 1 when the project has no tests, 2 when the runner is not installed.
jig_ts_test_cmd() {
  local root="$1" bin pm script
  if jig_ts_pkg_has "$root" vitest || compgen -G "$root/vitest.config.*" >/dev/null \
     || compgen -G "$root/vitest.workspace.*" >/dev/null \
     || [[ "$(jig_ts_tool "$root" vitest)" == */node_modules/.bin/vitest ]]; then
    bin="$(jig_ts_tool "$root" vitest)" || return 2
    printf '%s\n' "$bin" run --no-cache --passWithNoTests; return 0
  fi
  script="$(jq -r '.scripts.test // empty' "$root/package.json" 2>/dev/null)"
  [[ -n "$script" && "$script" != *"no test specified"* ]] || return 1
  pm="$(jig_ts_pm "$root")"
  command -v "$pm" >/dev/null || return 2
  # `bun test` is bun's own runner, not the script.
  if [[ "$pm" == bun ]]; then printf '%s\n' bun run test; else printf '%s\n' "$pm" test; fi
}

# Per-plugin state dir (survives plugin updates); temp dir outside Claude Code.
jig_ts_state_dir() {
  local d="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/jig-typescript}"
  mkdir -p "$d" && printf '%s\n' "$d"
}

# File listing TS/JS files edited in a session (one absolute path per line).
jig_ts_session_file() {
  local sid="${1//[^A-Za-z0-9_-]/_}"
  printf '%s/sessions/%s.files\n' "$(jig_ts_state_dir)" "${sid:-unknown}"
}
