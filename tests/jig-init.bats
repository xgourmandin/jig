#!/usr/bin/env bats
# Run: bats tests/
INIT="$BATS_TEST_DIRNAME/../bootstrap/jig-init"
HARNESS="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cd "$REPO" || return 1
  git init -q
}

add() { mkdir -p "$(dirname "$1")"; echo "${2:-x}" >"$1"; git add "$1"; }
init() { bash "$INIT" --no-install "$@"; }
enabled() { jq -r '.enabledPlugins | keys | join(",")' .claude/settings.json; }

@test "tf-only repo: core + terraform, terraform tooling and ADRs" {
  add infra/main.tf
  run init
  [ "$status" -eq 0 ]
  [ "$(enabled)" = "jig-core@jig,jig-terraform@jig" ]
  [ "$(jq -r .extraKnownMarketplaces.jig.source.source .claude/settings.json)" = git ]
  grep -q '^terraform = "' mise.toml
  grep -q '^tflint = ' mise.toml
  grep -q 'terraform-mcp-server" = ' mise.toml
  grep -q '"tflint --recursive"' mise.toml
  grep -q '^ARCHGATE_TELEMETRY = "0"' mise.toml
  [ -f .claude/rules/terraform.md ]
  [ -f .archgate/adrs/TF-001-pin-module-sources.rules.ts ]
  [ -f CLAUDE.md ] && [ -f docs/ai/ARCHITECTURE.md ]
  grep -qxF '.archgate/rules.d.ts' .gitignore
}

@test "py-only repo: core + python, python tooling, no terraform bits" {
  add app/main.py
  run init
  [ "$status" -eq 0 ]
  [ "$(enabled)" = "jig-core@jig,jig-python@jig" ]
  grep -q '^ruff = "' mise.toml
  grep -q '^uv = "' mise.toml
  grep -q '^"npm:pyright" = "' mise.toml
  grep -q '^node = "' mise.toml
  grep -q '"ruff check ."' mise.toml
  grep -q '"pyright"' mise.toml
  ! grep -q terraform mise.toml
  ! grep -q openwiki mise.toml
  [ ! -e .claude/rules/terraform.md ]
  [ ! -e .archgate/adrs/TF-001-pin-module-sources.md ]
  [ -f .archgate/adrs/GEN-001-record-decisions-as-adrs.md ]
}

@test "go repo: core + go, go tooling and lint, go pinned once" {
  add go.mod
  run init
  [ "$status" -eq 0 ]
  [ "$(enabled)" = "jig-core@jig,jig-go@jig" ]
  grep -q '^golangci-lint = "' mise.toml
  grep -q '^"go:golang.org/x/tools/gopls" = "' mise.toml
  grep -q '^"go:golang.org/x/tools/cmd/goimports" = "' mise.toml
  grep -q '"golangci-lint run ./..."' mise.toml
  grep -qF '"test -z \"$(gofmt -l .)\""' mise.toml
  [ "$(grep -c '^go = ' mise.toml)" -eq 1 ]
  ! grep -q terraform mise.toml
}

@test "ts repo with biome: biome pins and lint, tsc when tsconfig exists" {
  add package.json '{"name":"x"}'
  add biome.json '{}'
  add tsconfig.json '{}'
  run init
  [ "$status" -eq 0 ]
  [ "$(enabled)" = "jig-core@jig,jig-typescript@jig" ]
  grep -q '^"npm:typescript-language-server" = "' mise.toml
  grep -q '^"npm:@biomejs/biome" = "' mise.toml
  grep -q '^node = "' mise.toml
  ! grep -q 'npm:eslint' mise.toml
  grep -q '"biome ci ."' mise.toml
  grep -q '"tsc --noEmit"' mise.toml
  [[ "$output" == *"so the TypeScript LSP finds tsserver"* ]]
}

@test "ts repo with eslint + prettier: eslint and prettier, no biome" {
  add package.json '{"name":"x","devDependencies":{"prettier":"3"}}'
  add eslint.config.js 'export default []'
  run init
  grep -q '^"npm:eslint" = "' mise.toml
  grep -q '^"npm:prettier" = "' mise.toml
  ! grep -q 'biome' mise.toml
  grep -q '"eslint ."' mise.toml
  grep -q '"prettier --check ."' mise.toml
  ! grep -q '"tsc --noEmit"' mise.toml
}

@test "python + typescript: node pinned once" {
  add app/main.py
  add web/package.json '{"name":"x"}'
  init
  [ "$(grep -c '^node = ' mise.toml)" -eq 1 ]
}

@test "go + terraform: go pinned once" {
  add go.mod
  add infra/main.tf
  init
  [ "$(grep -c '^go = ' mise.toml)" -eq 1 ]
}

@test "mixed repo: terraform plugin enabled alongside core" {
  add infra/main.tf
  add app/pyproject.toml
  run init
  [ "$(enabled)" = "jig-core@jig,jig-python@jig,jig-terraform@jig" ]
}

@test "pins versions from the harness mise.toml" {
  add main.tf
  init
  want="$(awk -F' = ' '$1=="tflint"{print $2}' "$HARNESS/mise.toml")"
  grep -qxF "tflint = $want" mise.toml
}

@test "OpenTofu: --tofu or .opentofu-version pins opentofu and tofu lint" {
  add main.tf
  touch .opentofu-version
  init
  grep -q '^opentofu = ' mise.toml
  ! grep -q '^terraform = ' mise.toml
  grep -q '"tofu fmt -check -recursive"' mise.toml
}

@test "idempotent, keeps existing files and merges settings" {
  add main.tf
  mkdir -p .claude
  echo '{"permissions":{"allow":["Bash(ls)"]},"enabledPlugins":{"other@x":true}}' >.claude/settings.json
  echo "# mine" >CLAUDE.md
  init
  run init
  [ "$status" -eq 0 ]
  [[ "$output" == *"kept     CLAUDE.md"* ]]
  [ "$(cat CLAUDE.md)" = "# mine" ]
  [ "$(jq -r '.permissions.allow[0]' .claude/settings.json)" = "Bash(ls)" ]
  [ "$(enabled)" = "jig-core@jig,jig-terraform@jig,other@x" ]
  [ "$(grep -cxF '.archgate/rules.d.ts' .gitignore)" -eq 1 ]
}

@test "existing mise.toml is not touched" {
  add main.tf
  echo '[tools]' >mise.toml
  init
  [ "$(cat mise.toml)" = "[tools]" ]
}

@test "local marketplace dir becomes a directory source" {
  add main.tf
  init --marketplace-url "$HARNESS"
  [ "$(jq -r .extraKnownMarketplaces.jig.source.source .claude/settings.json)" = directory ]
  [ "$(jq -r .extraKnownMarketplaces.jig.source.path .claude/settings.json)" = "$HARNESS" ]
}

@test "--openwiki enables jig-openwiki and pins node + openwiki, no CI job" {
  add main.tf
  run init --openwiki
  [ "$status" -eq 0 ]
  [ "$(enabled)" = "jig-core@jig,jig-openwiki@jig,jig-terraform@jig" ]
  want="$(awk -F' = ' '$1=="\"npm:openwiki\""{print $2}' "$HARNESS/mise.toml")"
  grep -qxF "\"npm:openwiki\" = $want" mise.toml
  grep -q '^node = "' mise.toml
  grep -q '^OPENWIKI_TELEMETRY_DISABLED = "1"' mise.toml
  [[ "$output" == *"Initialize this repository's OpenWiki"* ]]
  [ ! -e .github ] && [ ! -e ci ]
}

@test "OpenWiki opt-in sticks: later runs without the flag keep the plugin" {
  add main.tf
  init --openwiki
  rm mise.toml
  run init
  [ "$status" -eq 0 ]
  [[ "$output" == *"jig-openwiki"* ]]
  grep -q '"npm:openwiki" = ' mise.toml
  # Or detected from an existing wiki.
  mkdir -p "$BATS_TEST_TMPDIR/r2" && cd "$BATS_TEST_TMPDIR/r2" && git init -q
  add openwiki/index.md
  run init
  [[ "$output" == *"jig-openwiki"* ]]
  [[ "$output" != *"Initialize this repository's OpenWiki"* ]]
}

@test "no OpenWiki unless asked; existing mise.toml gets a todo" {
  add main.tf
  init
  [[ "$(enabled)" != *openwiki* ]]
  ! grep -q openwiki mise.toml
  run init --openwiki
  [ "$status" -eq 0 ]
  [[ "$output" == *'todo     pin node and "npm:openwiki"'* ]]
}

@test "rejects bad options and non-git dirs" {
  run init --bogus
  [ "$status" -eq 64 ]
  mkdir -p "$BATS_TEST_TMPDIR/plain"
  GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run init "$BATS_TEST_TMPDIR/plain"
  [ "$status" -eq 65 ]
}

@test "generated ADRs pass archgate check on a clean tf repo" {
  command -v archgate >/dev/null || skip "archgate not installed"
  add main.tf 'module "m" { source = "./m" }'
  init
  ARCHGATE_TELEMETRY=0 run archgate check
  [ "$status" -eq 0 ]
}
