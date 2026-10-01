#!/usr/bin/env bats
# Run: bats tests/   (needs archgate from `mise install`)
# Each Terraform ADR rule must fail on a bad fixture and pass on a good one.
# Fixtures: tests/fixtures/tf-adr/<id>-<fail|pass>[-variant]/
TEMPLATES="$BATS_TEST_DIRNAME/../bootstrap/templates/archgate"
FIXTURES="$BATS_TEST_DIRNAME/fixtures/tf-adr"

setup() {
  command -v archgate >/dev/null || skip "archgate not installed (run mise install)"
  export ARCHGATE_TELEMETRY=0
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.archgate"
  cp -r "$TEMPLATES/." "$REPO/.archgate/"
  cd "$REPO" || return 1
  git init -q
}

use() { cp -r "$FIXTURES/$1/." "$REPO/"; }

# violation <rule> <file> <line>: check ran, failed, and pointed at the spot
violation() {
  [ "$status" -eq 1 ]
  [[ "$output" == *"\"ruleId\":\"$1\""* ]]
  [[ "$output" == *"\"file\":\"$2\",\"line\":$3"* ]]
}

@test "helper block is identical in every TF rule file" {
  cd "$TEMPLATES/adrs"
  ref=""
  for f in TF-0*.rules.ts; do
    [ "$f" = TF-001-pin-module-sources.rules.ts ] && continue
    block="$(sed -n '/<jig-hcl-helpers>/,/<\/jig-hcl-helpers>/p' "$f")"
    [ -n "$block" ]
    [ -z "$ref" ] && ref="$block"
    [ "$block" = "$ref" ] || { echo "$f differs"; return 1; }
  done
}

@test "all TF ADRs parse" {
  run archgate adr list
  [ "$status" -eq 0 ]
  for id in TF-001 TF-002 TF-003 TF-006 TF-007 TF-009; do [[ "$output" == *"$id"* ]]; done
}

# TF-002
@test "TF-002 fails on a provider block in a child module" {
  use 002-fail-provider
  run archgate check
  violation no-provider-or-backend-in-child-module modules/net/main.tf 1
}
@test "TF-002 fails on a backend block in a child module" {
  use 002-fail-backend
  run archgate check
  violation no-provider-or-backend-in-child-module modules/net/versions.tf 4
}
@test "TF-002 passes on required_providers, comments, examples and root providers" {
  use 002-pass
  run archgate check
  [ "$status" -eq 0 ]
}
@test "TF-002 honours jig:allow with a reason" {
  use 002-pass-allow
  run archgate check
  [ "$status" -eq 0 ]
}

# TF-006
@test "TF-006 fails on a root module with a provider and no lock file" {
  use 006-fail
  run archgate check
  violation root-module-has-lock-file live/dev/providers.tf 1
}
@test "TF-006 fails on a root module with a backend and no lock file" {
  use 006-fail-backend
  run archgate check
  violation root-module-has-lock-file live/dev/versions.tf 1
}
@test "TF-006 fails when the lock file is git-ignored (counts as missing)" {
  use 006-fail-ignored
  run archgate check
  violation root-module-has-lock-file live/dev/providers.tf 1
}
@test "TF-006 passes with a committed lock file" {
  use 006-pass
  run archgate check
  [ "$status" -eq 0 ]
}
@test "TF-006 ignores modules and examples" {
  use 006-pass-module-only
  run archgate check
  [ "$status" -eq 0 ]
}

# TF-007
@test "TF-007 fails on a prod database without prevent_destroy" {
  use 007-fail
  run archgate check
  violation stateful-resource-prevent-destroy live/prod/db.tf 1
}
@test "TF-007 fails on prevent_destroy = false" {
  use 007-fail-false
  run archgate check
  violation stateful-resource-prevent-destroy live/production/eu/db.tf 1
}
@test "TF-007 passes with prevent_destroy = true" {
  use 007-pass
  run archgate check
  [ "$status" -eq 0 ]
}
@test "TF-007 ignores non-production roots" {
  use 007-pass-nonprod
  run archgate check
  [ "$status" -eq 0 ]
}
@test "TF-007 honours jig:allow with a reason" {
  use 007-pass-allow
  run archgate check
  [ "$status" -eq 0 ]
}
@test "TF-007 rejects jig:allow without a reason" {
  use 007-fail-allow-no-reason
  run archgate check
  violation stateful-resource-prevent-destroy live/prod/db.tf 2
  [[ "$output" == *"needs a reason"* ]]
}

# TF-009
@test "TF-009 fails on a secret value in .tfvars" {
  use 009-fail-tfvars
  run archgate check
  violation no-secret-values live/dev/terraform.tfvars 2
}
@test "TF-009 fails on a secret variable without sensitive" {
  use 009-fail-sensitive
  run archgate check
  violation secret-variables-sensitive variables.tf 1
  [[ "$output" == *"sensitive = true"* ]]
}
@test "TF-009 fails on a secret variable with a default" {
  use 009-fail-default
  run archgate check
  violation secret-variables-sensitive variables.tf 1
  [[ "$output" == *"remove its default"* ]]
}
@test "TF-009 fails on access key material" {
  use 009-fail-key-material
  run archgate check
  violation no-secret-values main.tf 2
}
@test "TF-009 passes on sensitive variables, non-secret names and commented values" {
  use 009-pass
  run archgate check
  [ "$status" -eq 0 ]
}
@test "TF-009 honours jig:allow with a reason" {
  use 009-pass-allow
  run archgate check
  [ "$status" -eq 0 ]
}

# False-positive guard
@test "the tf-sample fixture passes every ADR" {
  cp -r "$BATS_TEST_DIRNAME/fixtures/tf-sample/." "$REPO/"
  run archgate check
  [ "$status" -eq 0 ]
}

# Drift: ADR templates and skills must stay in sync
@test "every TF ADR template is referenced by the conventions skill and the other way round" {
  skill="$BATS_TEST_DIRNAME/../plugins/jig-terraform/skills/terraform-conventions/SKILL.md"
  for f in "$TEMPLATES"/adrs/TF-*.md; do
    id="$(basename "$f" | cut -d- -f1-2)"
    grep -q "$id" "$skill" || { echo "$id missing from $skill"; return 1; }
  done
  for id in $(grep -o 'TF-0[0-9][0-9]' "$skill" | sort -u); do
    ls "$TEMPLATES"/adrs/"$id"-*.md >/dev/null || { echo "$id has no ADR template"; return 1; }
  done
}

@test "TF ADRs stay out of a Python-only change even if the files are present" {
  mkdir src
  echo 'x = 1' >src/app.py
  git add -A && git -c user.name=t -c user.email=t@t commit -qm base
  echo 'y = 2' >>src/app.py
  run archgate check
  [ "$status" -eq 0 ]
  run archgate review-context
  [[ "$output" == *"GEN-001"* ]]
  [[ "$output" != *'"id":"TF-'* ]]
}
