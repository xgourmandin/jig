#!/usr/bin/env bats
# Run: bats tests/   (needs archgate from `mise install`)
# The ADR templates that jig-init copies must be valid and actually enforce.
TEMPLATES="$BATS_TEST_DIRNAME/../bootstrap/templates/archgate"

setup() {
  command -v archgate >/dev/null || skip "archgate not installed (run mise install)"
  export ARCHGATE_TELEMETRY=0
  # archgate picks its human console reporter when CI is set and machine-readable
  # JSON otherwise. `review-context` has no --output flag, so clearing CI is the
  # only way to pin the format these tests assert on. See the two format tests below.
  unset CI
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.archgate"
  cp -r "$TEMPLATES/." "$REPO/.archgate/"
  cd "$REPO" || return 1
  git init -q
}

module() { printf 'module "vpc" {\n  source = "%s"\n}\n' "$1" >main.tf; }

@test "TF-001 fails on an unpinned git module source" {
  module "git::https://git.example.com/infra/modules.git//vpc"
  run archgate check
  [ "$status" -eq 1 ]
  [[ "$output" == *"git-source-has-ref"* ]]
  [[ "$output" == *'"file":"main.tf","line":2'* ]]
}

@test "TF-001 passes on a pinned git module source" {
  module "git::https://git.example.com/infra/modules.git//vpc?ref=v1.4.0"
  run archgate check
  [ "$status" -eq 0 ]
}

@test "TF-001 ignores local and registry sources" {
  module "./modules/vpc"
  run archgate check
  [ "$status" -eq 0 ]
}

@test "archgate reports in JSON, which every ADR assertion parses" {
  module "git::https://git.example.com/infra/modules.git//vpc"
  run archgate check
  [ "$status" -eq 1 ]
  jq -e . <<<"$output" >/dev/null
}

@test "a CI environment switches archgate off JSON (why setup unsets CI)" {
  module "git::https://git.example.com/infra/modules.git//vpc"
  CI=true run archgate check
  [ "$status" -eq 1 ]
  ! jq -e . <<<"$output" >/dev/null 2>&1
}

@test "all template ADRs parse" {
  run archgate adr list
  [ "$status" -eq 0 ]
  [[ "$output" == *"GEN-001"* ]]
  [[ "$output" == *"TF-001"* ]]
}
