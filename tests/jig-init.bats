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

@test "py-only repo: core only (jig-python not built yet), no terraform bits" {
  add app/main.py
  run init
  [ "$status" -eq 0 ]
  [[ "$output" == *"jig-python does not exist yet"* ]]
  [ "$(enabled)" = "jig-core@jig" ]
  ! grep -q terraform mise.toml
  [ ! -e .claude/rules/terraform.md ]
  [ ! -e .archgate/adrs/TF-001-pin-module-sources.md ]
  [ -f .archgate/adrs/GEN-001-record-decisions-as-adrs.md ]
}

@test "mixed repo: terraform plugin enabled alongside core" {
  add infra/main.tf
  add app/pyproject.toml
  run init
  [ "$(enabled)" = "jig-core@jig,jig-terraform@jig" ]
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

@test "--openwiki github writes the workflow; gitlab writes the include" {
  add main.tf
  init --openwiki github
  grep -q 'OPENWIKI_PROVIDER: anthropic' .github/workflows/openwiki-update.yml
  run init --openwiki gitlab
  [ -f ci/openwiki.gitlab-ci.yml ]
  [[ "$output" == *"include ci/openwiki.gitlab-ci.yml"* ]]
}

@test "no OpenWiki job unless asked" {
  add main.tf
  init
  [ ! -e .github/workflows/openwiki-update.yml ]
  [ ! -e ci/openwiki.gitlab-ci.yml ]
}

@test "rejects bad options and non-git dirs" {
  run init --openwiki bitbucket
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
