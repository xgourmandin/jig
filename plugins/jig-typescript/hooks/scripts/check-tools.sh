#!/usr/bin/env bash
# SessionStart: warn (in Claude's context) when required binaries are missing,
# so Claude tells the user instead of silently degrading.
set -uo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"
{ git ls-files 2>/dev/null || ls; } | grep -Eq '(^|/)package\.json$|\.(ts|tsx|mts|cts)$' || exit 0
root="$(pwd)"
missing=()
# The LSP binary comes from PATH only (the typescript-lsp plugin starts it).
command -v typescript-language-server >/dev/null || missing+=(typescript-language-server)
jig_ts_tool "$root" tsc >/dev/null || missing+=(tsc)
case "$(jig_ts_linter "$root")" in
  biome) jig_ts_tool "$root" biome >/dev/null || missing+=(biome) ;;
  eslint) jig_ts_tool "$root" eslint >/dev/null || missing+=(eslint) ;;
esac
if [[ "$(jig_ts_linter "$root")" != biome ]] && jig_ts_uses_prettier "$root"; then
  jig_ts_tool "$root" prettier >/dev/null || missing+=(prettier)
fi
msg=""
if (( ${#missing[@]} )); then
  list="$(IFS=,; echo "${missing[*]}")"
  msg+="Jig typescript: missing tools: ${list//,/, }. Tell the user to run 'mise install' in this repo. Code intelligence and edit checks are degraded until then. "
fi
# typescript-language-server uses the project's own TypeScript (tsserver).
if [[ -f package.json && ! -d node_modules ]]; then
  msg+="Jig typescript: node_modules is missing, so the TypeScript LSP, type checks and tests cannot resolve dependencies. Ask the user to install them (e.g. 'npm ci'); do not install them yourself."
elif [[ -d node_modules && ! -f node_modules/typescript/lib/tsserver.js ]] && jig_ts_pkg_has "$root" typescript; then
  msg+="Jig typescript: node_modules/typescript has no tsserver (TypeScript 7 or not installed), so the TypeScript LSP cannot start. Tell the user."
fi
[[ -n "$msg" ]] && echo "${msg% }"
exit 0
