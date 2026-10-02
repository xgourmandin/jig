#!/usr/bin/env bats
# Run: bats tests/   (needs archgate from `mise install`)
# Each Python ADR rule must fail on a bad fixture and pass on a good one.
# Fixtures: tests/fixtures/py-adr/<id>-<fail|pass>[-variant]/  (layout: src/shop/<layer>/)
TEMPLATES="$BATS_TEST_DIRNAME/../bootstrap/templates/archgate"
FIXTURES="$BATS_TEST_DIRNAME/fixtures/py-adr"

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

passes() {
  use "$1"
  run archgate check
  [ "$status" -eq 0 ]
}

@test "helper block is identical in every PY rule file" {
  cd "$TEMPLATES/adrs"
  ref=""
  n=0
  for f in PY-0*.rules.ts; do
    block="$(sed -n '/<jig-py-helpers>/,/<\/jig-py-helpers>/p' "$f")"
    [ -n "$block" ]
    [ -z "$ref" ] && ref="$block"
    [ "$block" = "$ref" ] || { echo "$f differs"; return 1; }
    n=$((n + 1))
  done
  [ "$n" -ge 7 ]
}

@test "all PY ADRs parse" {
  run archgate adr list
  [ "$status" -eq 0 ]
  for id in PY-001 PY-002 PY-003 PY-004 PY-005 PY-006 PY-007 PY-008; do [[ "$output" == *"$id"* ]]; done
}

# PY-001
@test "PY-001 fails on a framework import in the domain" {
  use 001-fail-framework
  run archgate check
  violation domain-imports-nothing-outward src/shop/domain/order.py 1
  [[ "$output" == *"sqlalchemy"* ]]
}
@test "PY-001 fails on an absolute adapter import in the domain" {
  use 001-fail-adapter
  run archgate check
  violation domain-imports-nothing-outward src/shop/domain/order.py 3
}
@test "PY-001 fails on a relative adapter import in the domain" {
  use 001-fail-relative
  run archgate check
  violation domain-imports-nothing-outward src/shop/domain/order.py 3
}
@test "PY-001 fails on an application import in the domain" {
  use 001-fail-application
  run archgate check
  violation domain-imports-nothing-outward src/shop/domain/order.py 1
}
@test "PY-001 rejects archgate-ignore without a reason" {
  use 001-fail-allow-no-reason
  run archgate check
  violation domain-imports-nothing-outward src/shop/domain/order.py 3
  [[ "$output" == *"missing a reason"* ]]
}
@test "PY-001 passes on stdlib, domain-relative imports, comments and strings" {
  passes 001-pass
}
@test "PY-001 honours archgate-ignore with a reason" {
  passes 001-pass-allow
}

# PY-002
@test "PY-002 fails when the application imports an adapter" {
  use 002-fail-adapter
  run archgate check
  violation application-depends-inward-only src/shop/application/place_order.py 2
}
@test "PY-002 fails on a relative adapters import in the application" {
  use 002-fail-relative
  run archgate check
  violation application-depends-inward-only src/shop/application/place_order.py 1
}
@test "PY-002 fails on a framework import in ports" {
  use 002-fail-framework
  run archgate check
  violation application-depends-inward-only src/shop/ports/orders.py 2
}
@test "PY-002 fails when the application imports bootstrap" {
  use 002-fail-bootstrap
  run archgate check
  violation application-depends-inward-only src/shop/application/place_order.py 1
}
@test "PY-002 passes on domain/ports imports and wiring in bootstrap" {
  passes 002-pass
}

# PY-003
@test "PY-003 fails when an adapter imports another adapter" {
  use 003-fail-cross
  run archgate check
  violation adapters-do-not-import-each-other src/shop/adapters/postgres/orders.py 2
}
@test "PY-003 fails on a relative import of a sibling adapter" {
  use 003-fail-cross-relative
  run archgate check
  violation adapters-do-not-import-each-other src/shop/adapters/postgres/orders.py 1
}
@test "PY-003 fails when an adapter imports bootstrap" {
  use 003-fail-bootstrap
  run archgate check
  violation adapters-do-not-import-each-other src/shop/adapters/postgres/orders.py 1
}
@test "PY-003 passes on inward imports, frameworks and the adapter's own modules" {
  passes 003-pass
}

# PY-004
@test "PY-004 fails on an ABC defined in an adapter" {
  use 004-fail-adapter
  run archgate check
  violation ports-defined-inside-not-in-adapters src/shop/adapters/postgres/base.py 8
}
@test "PY-004 fails on a Protocol defined in an adapter" {
  use 004-fail-adapter-protocol
  run archgate check
  violation ports-defined-inside-not-in-adapters src/shop/adapters/http/client.py 5
}
@test "PY-004 fails on a concrete *Repository class in ports" {
  use 004-fail-port-concrete
  run archgate check
  violation ports-defined-inside-not-in-adapters src/shop/ports/orders.py 1
}
@test "PY-004 passes on Protocols in ports and adapters implementing them" {
  passes 004-pass
}

# PY-005
@test "PY-005 fails on a wildcard import" {
  use 005-fail
  run archgate check
  violation no-wildcard-imports src/shop/util.py 2
}
@test "PY-005 passes on named imports, comments and archgate-ignore with a reason" {
  passes 005-pass
}

# PY-006
@test "PY-006 fails on mutable defaults, including multi-line signatures" {
  use 006-fail-default
  run archgate check
  violation no-mutable-default-args src/shop/util.py 1
  [[ "$output" == *"\"file\":\"src/shop/util.py\",\"line\":7"* ]]
}
@test "PY-006 fails on set()/defaultdict() defaults" {
  use 006-fail-default-call
  run archgate check
  violation no-mutable-default-args src/shop/util.py 4
}
@test "PY-006 fails on a bare except" {
  use 006-fail-except
  run archgate check
  violation no-bare-except src/shop/util.py 4
}
@test "PY-006 passes on immutable defaults, typed excepts and archgate-ignore" {
  passes 006-pass
}

# PY-007
@test "PY-007 fails on os.environ[...] at import time in the domain" {
  use 007-fail-open
  run archgate check
  violation no-import-time-io src/shop/domain/config.py 3
}
@test "PY-007 fails on os.getenv at import time in the application" {
  use 007-fail-getenv
  run archgate check
  violation no-import-time-io src/shop/application/settings.py 3
}
@test "PY-007 fails on print at import time in ports" {
  use 007-fail-print
  run archgate check
  violation no-import-time-io src/shop/ports/p.py 1
}
@test "PY-007 fails on open() at import time" {
  use 007-fail-open-read
  run archgate check
  violation no-import-time-io src/shop/domain/data.py 1
}
@test "PY-007 passes on I/O inside functions and in adapters/bootstrap" {
  passes 007-pass
}
@test "PY-007 honours archgate-ignore with a reason" {
  passes 007-pass-allow
}

# False-positive guard
@test "the py-sample fixture passes every ADR" {
  passes py-sample
}

# Stack gating: ADRs are scoped by `files`, so they only show up for matching changes
@test "PY ADRs stay out of a Terraform-only change even if the files are present" {
  mkdir infra
  echo 'variable "x" {}' >infra/main.tf
  git add -A && git -c user.name=t -c user.email=t@t commit -qm base
  echo '# change' >>infra/main.tf
  run archgate check
  [ "$status" -eq 0 ]
  run archgate review-context
  [[ "$output" == *"GEN-001"* ]]
  [[ "$output" != *'"id":"PY-'* ]]
}

@test "PY ADRs apply to a Python change" {
  mkdir -p src/shop/domain
  echo 'x = 1' >src/shop/domain/a.py
  git add -A && git -c user.name=t -c user.email=t@t commit -qm base
  echo 'y = 2' >>src/shop/domain/a.py
  run archgate review-context
  [[ "$output" == *'"id":"PY-001"'* ]]
}
