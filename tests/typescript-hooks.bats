#!/usr/bin/env bats
# Run: bats tests/   (needs tsc, biome, vitest, eslint, prettier from `mise install`)
SCRIPTS="$BATS_TEST_DIRNAME/../plugins/jig-typescript/hooks/scripts"
FIXTURE="$BATS_TEST_DIRNAME/fixtures/ts-sample"

# Package dir of a mise-installed npm tool, found from its bin on PATH.
npm_pkg() { readlink -f "$(dirname "$(command -v "$1")")/../$2"; }

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cp -r "$FIXTURE/." "$REPO/"
  cd "$REPO" || return 1
  git init -q -b main
  # What `npm ci` would give (offline): the fixture's devDependencies.
  rm -rf node_modules && mkdir node_modules
  ln -s "$(npm_pkg tsc typescript)" node_modules/typescript
  ln -s "$(npm_pkg vitest vitest)" node_modules/vitest
  export CLAUDE_PLUGIN_DATA="$BATS_TEST_TMPDIR/data"
  STATE="$CLAUDE_PLUGIN_DATA/sessions/s1.files"
}

edit()  { jq -nc --arg f "$1" '{session_id:"s1",tool_name:"Edit",tool_input:{file_path:$f}}' | bash "$SCRIPTS/ts-post-edit.sh"; }
stop()  { jq -nc --argjson a "${1:-false}" '{session_id:"s1",hook_event_name:"Stop",stop_hook_active:$a}' | bash "$SCRIPTS/ts-stop-check.sh"; }
CALC="src/calc.ts"

# The repo defines a mise lint task (jig-core runs it); a fake mise is enough here.
with_lint_task() {
  printf '\n[tasks.lint]\nrun = "true"\n' >>mise.toml
  MISEBIN="$BATS_TEST_TMPDIR/misebin"; mkdir -p "$MISEBIN"
  printf '#!/bin/sh\nexit 0\n' >"$MISEBIN/mise"; chmod +x "$MISEBIN/mise"
  export PATH="$MISEBIN:$PATH"
}
lib()   { bash -c "source '$SCRIPTS/lib.sh'; $1"; }

# Switch the fixture from biome to eslint (+ prettier with $1 = prettier).
use_eslint() {
  rm biome.json
  cat >eslint.config.mjs <<'EOF'
export default [
  { ignores: ["legacy/**"] },
  { files: ["**/*.{js,mjs,cjs}"], rules: { "prefer-const": "error", "no-undef": "error" } },
];
EOF
  [[ "${1:-}" == prettier ]] && echo '{ "semi": true }' >.prettierrc.json
  return 0
}

# Directory of fake binaries, to control what is "installed".
stub_bin() {
  STUBS="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$STUBS"
  for b in "$@"; do printf '#!/bin/sh\nexit 0\n' >"$STUBS/$b"; chmod +x "$STUBS/$b"; done
  for b in bash jq git grep mkdir dirname cat sort head tail rm basename cksum cut ls; do ln -sf "$(command -v "$b")" "$STUBS/$b"; done
}

# --- lib -----------------------------------------------------------------------
@test "root: nearest package.json, not above the git root" {
  mkdir -p pkgs/api/src && echo '{}' >pkgs/api/package.json && touch pkgs/api/src/x.ts
  run lib "jig_ts_root '$REPO/pkgs/api/src/x.ts'"
  [ "$output" = "$REPO/pkgs/api" ]
  run lib "jig_ts_root '$REPO/$CALC'"
  [ "$output" = "$REPO" ]
}
@test "root: git root when there is no package.json" {
  rm package.json; mkdir -p a && touch a/x.ts
  run lib "jig_ts_root '$REPO/a/x.ts'"
  [ "$output" = "$REPO" ]
}
@test "tool: node_modules/.bin (also hoisted) wins over PATH" {
  mkdir -p node_modules/.bin pkgs/api && echo '{}' >pkgs/api/package.json
  printf '#!/bin/sh\n' >node_modules/.bin/tsc && chmod +x node_modules/.bin/tsc
  run lib "jig_ts_tool '$REPO/pkgs/api' tsc"
  [ "$output" = "$REPO/node_modules/.bin/tsc" ]
  run lib "jig_ts_tool '$REPO' biome"
  [ "$output" = "$(command -v biome)" ]
}
@test "linter: biome.json -> biome, eslint config -> eslint, else none" {
  run lib "jig_ts_linter '$REPO'";  [ "$output" = biome ]
  use_eslint
  run lib "jig_ts_linter '$REPO'";  [ "$output" = eslint ]
  rm eslint.config.mjs && jq '. + {eslintConfig: {}}' package.json >p && mv p package.json
  run lib "jig_ts_linter '$REPO'";  [ "$output" = eslint ]
  jq 'del(.eslintConfig)' package.json >p && mv p package.json
  run lib "jig_ts_linter '$REPO'";  [ "$output" = none ]
}
@test "prettier: used only with a config or a dependency" {
  run lib "jig_ts_uses_prettier '$REPO'"; [ "$status" -eq 1 ]
  echo '{}' >.prettierrc; run lib "jig_ts_uses_prettier '$REPO'"; [ "$status" -eq 0 ]
  rm .prettierrc && jq '.devDependencies.prettier = "3"' package.json >p && mv p package.json
  run lib "jig_ts_uses_prettier '$REPO'"; [ "$status" -eq 0 ]
}
@test "package manager: from lockfile, packageManager, else npm" {
  run lib "jig_ts_pm '$REPO'"; [ "$output" = npm ]
  jq '.packageManager = "yarn@4.1.0"' package.json >p && mv p package.json
  run lib "jig_ts_pm '$REPO'"; [ "$output" = yarn ]
  touch pnpm-lock.yaml; run lib "jig_ts_pm '$REPO'"; [ "$output" = pnpm ]
  rm pnpm-lock.yaml; touch bun.lock; run lib "jig_ts_pm '$REPO'"; [ "$output" = bun ]
}
@test "tests: vitest when it is a dependency" {
  run lib "jig_ts_test_cmd '$REPO'"
  [ "$output" = "$(command -v vitest)"$'\nrun\n--no-cache\n--passWithNoTests' ]
}
@test "tests: package manager test script without vitest" {
  stub_bin pnpm bun
  jq 'del(.devDependencies.vitest) | .scripts.test = "jest"' package.json >p && mv p package.json
  touch pnpm-lock.yaml
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_ts_test_cmd '$REPO'"
  [ "$output" = $'pnpm\ntest' ]
  rm pnpm-lock.yaml; touch bun.lockb
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_ts_test_cmd '$REPO'"
  [ "$output" = $'bun\nrun\ntest' ]
}
@test "tests: none for npm's default stub or no script; 2 when runner missing" {
  stub_bin
  jq 'del(.devDependencies.vitest) | .scripts.test = "echo \"Error: no test specified\" && exit 1"' package.json >p && mv p package.json
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_ts_test_cmd '$REPO'"
  [ "$status" -eq 1 ]
  jq 'del(.scripts)' package.json >p && mv p package.json
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_ts_test_cmd '$REPO'"
  [ "$status" -eq 1 ]
  jq '.devDependencies.vitest = "5"' package.json >p && mv p package.json
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_ts_test_cmd '$REPO'"
  [ "$status" -eq 2 ]
}

# --- PostToolUse: ts-post-edit.sh ----------------------------------------------
@test "post-edit: ignores non-TS/JS files" {
  echo x >README.md
  run edit "$REPO/README.md"
  [ "$status" -eq 0 ]
  [ ! -e "$STATE" ]
}
@test "post-edit: clean file passes and is recorded once" {
  run edit "$REPO/$CALC"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ "$(cat "$STATE")" = "$REPO/$CALC" ]
  run edit "$REPO/$CALC"
  [ "$(wc -l <"$STATE")" -eq 1 ]
}
@test "biome: formats the file and applies safe fixes" {
  printf 'import {add} from "./calc.js"\nexport function twice( x:number ):number {\n    let y = add(x,x)\n  return y }\n' >src/extra.ts
  run edit "$REPO/src/extra.ts"
  [ "$status" -eq 0 ]
  grep -q '^import { add } from "./calc.js";$' src/extra.ts
  grep -q '^  const y = add(x, x);$' src/extra.ts
}
@test "biome: remaining lint error blocks with biome output" {
  printf 'export function f(a: number): boolean {\n  debugger;\n  return a === 1;\n}\n' >src/lint.ts
  run edit "$REPO/src/lint.ts"
  [ "$status" -eq 2 ]
  [[ "$output" == *"biome check reported errors"*"src/lint.ts:2:3: lint/suspicious/noDebugger"* ]]
}
@test "biome: syntax error blocks" {
  printf 'export const x = (\n' >src/bad.ts
  run edit "$REPO/src/bad.ts"
  [ "$status" -eq 2 ]
  [[ "$output" == *"src/bad.ts:2:1: parse"* ]]
}
@test "biome: respects the repo's ignore files" {
  echo 'gen/' >>.gitignore; mkdir gen && printf 'export const  y=1;debugger\n' >gen/a.ts
  run edit "$REPO/gen/a.ts"
  [ "$status" -eq 0 ]
  grep -q 'const  y=1' gen/a.ts
}
@test "eslint: prettier formats, eslint fixes, clean file passes" {
  use_eslint prettier
  printf "const a=1\nexport function f( ){ let b = a+1; return b }\n" >src/ok.js
  run edit "$REPO/src/ok.js"
  [ "$status" -eq 0 ]
  grep -q '^  const b = a + 1;$' src/ok.js
}
@test "eslint: remaining error blocks with rule and location" {
  use_eslint prettier
  printf 'export function g() {\n  return missing + 1;\n}\n' >src/bad.js
  run edit "$REPO/src/bad.js"
  [ "$status" -eq 2 ]
  [[ "$output" == *"eslint reported errors"*"src/bad.js:2:10 no-undef"* ]]
}
@test "eslint: prettier syntax error blocks before eslint runs" {
  use_eslint prettier
  printf 'const x = (\n' >src/syn.js
  run edit "$REPO/src/syn.js"
  [ "$status" -eq 2 ]
  [[ "$output" == *"prettier failed"* ]]
}
@test "eslint: no prettier in the repo -> file is not reformatted" {
  use_eslint
  printf 'export const  y = 1\n' >src/raw.js
  run edit "$REPO/src/raw.js"
  [ "$status" -eq 0 ]
  grep -q 'const  y = 1$' src/raw.js
}
@test "eslint: respects the config's ignores" {
  use_eslint
  mkdir legacy && printf 'x = undefinedThing;\n' >legacy/old.js
  run edit "$REPO/legacy/old.js"
  [ "$status" -eq 0 ]
}
@test "eslint: broken config warns the user, does not block" {
  use_eslint; echo 'export default [ {' >eslint.config.mjs
  run edit "$REPO/$CALC"
  [ "$status" -eq 0 ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"eslint could not run"* ]]
}
@test "post-edit: no tools installed is a no-op (still recorded)" {
  stub_bin
  run env PATH="$STUBS" bash -c "jq -nc --arg f '$REPO/$CALC' '{session_id:\"s1\",tool_input:{file_path:\$f}}' | bash '$SCRIPTS/ts-post-edit.sh'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ -s "$STATE" ]
}

# --- Stop: ts-stop-check.sh ----------------------------------------------------
@test "stop: nothing edited -> allow silently" {
  run stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
@test "stop: clean edits pass and clear the session list" {
  edit "$REPO/$CALC"
  run stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$STATE" ]
}
@test "stop: type error blocks once with tsc output" {
  printf '\nexport function twice(x: number): string {\n  return x * 2;\n}\n' >>"$CALC"
  edit "$REPO/$CALC"
  run stop
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(tsc)"*"src/calc.ts("*"error TS2322"* ]]
  [ -s "$STATE" ]
  run stop true
  [ "$(jq -r '.decision // empty' <<<"$output")" = "" ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"checks still fail after Claude's fix"*"error TS2322"* ]]
  [ -s "$STATE" ]
}
@test "stop: re-check after a block passes silently and clears the list" {
  edit "$REPO/$CALC"
  run stop true
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$STATE" ]
}
@test "stop: lint task present -> tsc skipped" {
  with_lint_task
  printf '\nexport function twice(x: number): string {\n  return x * 2;\n}\n' >>"$CALC"
  edit "$REPO/$CALC"
  run stop
  [ -z "$output" ]
}
@test "stop: failing test blocks with vitest output" {
  sed -i 's/return a + b/return a - b/' "$CALC"
  edit "$REPO/$CALC"
  run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(vitest, exit 1)"*"add"* ]]
}
@test "stop: no test files is fine" {
  rm src/calc.test.ts
  edit "$REPO/$CALC"
  run stop
  [ -z "$output" ]
}
@test "stop: runs the package manager's test script without vitest" {
  stub_bin tsc
  printf '#!/bin/sh\necho "1 failing: $*"; exit 3\n' >"$STUBS/npm"; chmod +x "$STUBS/npm"
  rm node_modules/vitest
  jq 'del(.devDependencies.vitest) | .scripts.test = "jest"' package.json >p && mv p package.json
  edit "$REPO/$CALC"
  run env PATH="$STUBS" bash -c "jq -nc '{session_id:\"s1\"}' | bash '$SCRIPTS/ts-stop-check.sh'"
  [[ "$(jq -r .reason <<<"$output")" == *"(npm test, exit 3)"*"1 failing: test"* ]]
}
@test "stop: leaves no cache or build info files in the repo" {
  jq '.compilerOptions.incremental = true' tsconfig.json >t && mv t tsconfig.json
  edit "$REPO/$CALC"
  run stop
  [ -z "$output" ]
  [ -z "$(git status --porcelain --ignored | grep -v '^!! node_modules/$' | grep -v '^??')" ]
  [ -z "$(find . -name '*.tsbuildinfo' -not -path './node_modules/*')" ]
  [ "$(ls -A node_modules | tr '\n' ' ')" = "typescript vitest " ]
}
@test "stop: missing tools only warn" {
  stub_bin
  rm node_modules/vitest
  edit "$REPO/$CALC"
  run env PATH="$STUBS" bash -c "jq -nc '{session_id:\"s1\"}' | bash '$SCRIPTS/ts-stop-check.sh'"
  [ "$status" -eq 0 ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"tsc not found"*"test runner not found"* ]]
}

# --- SessionStart: check-tools.sh ----------------------------------------------
@test "check-tools: silent when tools are installed" {
  git add -A
  run bash "$SCRIPTS/check-tools.sh"
  [ -z "$output" ]
}
@test "check-tools: names missing tools" {
  git add -A; stub_bin
  run env PATH="$STUBS" bash "$SCRIPTS/check-tools.sh"
  [[ "$output" == *"missing tools: typescript-language-server, tsc, biome"* ]]
}
@test "check-tools: eslint + prettier repos need eslint and prettier" {
  use_eslint prettier; git add -A; stub_bin typescript-language-server tsc
  run env PATH="$STUBS" bash "$SCRIPTS/check-tools.sh"
  [[ "$output" == *"missing tools: eslint, prettier"* ]]
}
@test "check-tools: warns when node_modules is missing or has no tsserver" {
  git add -A; rm -rf node_modules
  run bash "$SCRIPTS/check-tools.sh"
  [[ "$output" == *"node_modules is missing"* ]]
  mkdir -p node_modules/typescript/lib
  run bash "$SCRIPTS/check-tools.sh"
  [[ "$output" == *"no tsserver"* ]]
}
@test "check-tools: silent in repos without TS/JS" {
  rm -rf src package.json tsconfig.json; stub_bin
  run env PATH="$STUBS" bash "$SCRIPTS/check-tools.sh"
  [ -z "$output" ]
}
