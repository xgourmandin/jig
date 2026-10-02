#!/usr/bin/env bats
# Run: bats tests/   (needs archgate from `mise install`)
# Each Go ADR rule must fail on a bad fixture and pass on a good one.
# Fixtures: tests/fixtures/go-adr/<id>-<fail|pass>[-variant]/
TEMPLATES="$BATS_TEST_DIRNAME/../bootstrap/templates/archgate"
FIXTURES="$BATS_TEST_DIRNAME/fixtures/go-adr"

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

@test "helper block is identical in every GO rule file" {
  cd "$TEMPLATES/adrs"
  ref=""
  n=0
  for f in GO-0*.rules.ts; do
    block="$(sed -n '/<jig-go-helpers>/,/<\/jig-go-helpers>/p' "$f")"
    [ -n "$block" ]
    [ -z "$ref" ] && ref="$block"
    [ "$block" = "$ref" ] || { echo "$f differs"; return 1; }
    n=$((n + 1))
  done
  [ "$n" -eq 8 ]
}

@test "all GO ADRs parse" {
  run archgate adr list
  [ "$status" -eq 0 ]
  for id in GO-001 GO-002 GO-003 GO-004 GO-005 GO-006 GO-007 GO-008 GO-009; do [[ "$output" == *"$id"* ]]; done
}

# GO-001
@test "GO-001 fails on net/http in the domain" {
  use 001-fail-http
  run archgate check
  violation domain-is-pure internal/domain/order.go 5
}
@test "GO-001 fails on an adapter import in the domain" {
  use 001-fail-adapter
  run archgate check
  violation domain-is-pure internal/domain/order.go 3
}
@test "GO-001 fails on an ORM import with an alias" {
  use 001-fail-sdk
  run archgate check
  violation domain-is-pure internal/domain/order.go 5
}
@test "GO-001 passes on a pure domain; comments, strings and tests are ignored" {
  passes 001-pass
}
@test "GO-001 honours archgate-ignore with a reason" {
  passes 001-pass-allow
}
@test "GO-001 rejects archgate-ignore without a reason" {
  use 001-fail-allow-no-reason
  run archgate check
  violation domain-is-pure internal/domain/order.go 5
  [[ "$output" == *"missing a reason"* ]]
}

# GO-002
@test "GO-002 fails when app imports an adapter" {
  use 002-fail-adapter
  run archgate check
  violation app-and-ports-depend-inward internal/app/place.go 4
}
@test "GO-002 fails when a port imports database/sql" {
  use 002-fail-sql
  run archgate check
  violation app-and-ports-depend-inward internal/ports/repo.go 3
}
@test "GO-002 fails when ports import app" {
  use 002-fail-ports-app
  run archgate check
  violation app-and-ports-depend-inward internal/ports/repo.go 3
}
@test "GO-002 passes when app depends on domain and ports" {
  passes 002-pass
}

# GO-003
@test "GO-003 fails when an adapter imports another adapter" {
  use 003-fail
  run archgate check
  violation adapters-are-independent internal/adapters/http/handler.go 3
}
@test "GO-003 fails when an adapter imports cmd" {
  use 003-fail-cmd
  run archgate check
  violation adapters-are-independent internal/adapters/http/handler.go 3
}
@test "GO-003 passes on inward imports and the adapter's own sub-packages" {
  passes 003-pass
}

# GO-004
@test "GO-004 fails on an exported interface in an adapter" {
  use 004-fail
  run archgate check
  violation adapters-do-not-define-ports internal/adapters/postgres/repo.go 5
}
@test "GO-004 fails on an exported interface in a type block" {
  use 004-fail-block
  run archgate check
  violation adapters-do-not-define-ports internal/adapters/postgres/repo.go 5
}
@test "GO-004 passes on unexported interfaces, ports and commented code" {
  passes 004-pass
}

# GO-005
@test "GO-005 fails on init()" {
  use 005-fail-init
  run archgate check
  violation no-init internal/store/store.go 3
}
@test "GO-005 fails on panic" {
  use 005-fail-panic
  run archgate check
  violation no-panic internal/store/store.go 5
}
@test "GO-005 fails on a package-level variable" {
  use 005-fail-global
  run archgate check
  violation no-global-mutable-state internal/store/store.go 3
}
@test "GO-005 fails on a variable in a var block" {
  use 005-fail-global-block
  run archgate check
  violation no-global-mutable-state internal/store/store.go 7
}
@test "GO-005 passes on sentinels, embed, regexp, package main and tests" {
  passes 005-pass
}
@test "GO-005 honours archgate-ignore with a reason" {
  passes 005-pass-allow
}

# GO-006
@test "GO-006 fails on fmt.Errorf with err and %v" {
  use 006-fail-wrap
  run archgate check
  violation wrap-errors-with-w internal/store/store.go 8
}
@test "GO-006 fails on a multi-line fmt.Errorf with err and %v" {
  use 006-fail-wrap-multiline
  run archgate check
  violation wrap-errors-with-w internal/store/store.go 6
}
@test "GO-006 fails on a silently ignored result" {
  use 006-fail-ignored
  run archgate check
  violation no-ignored-errors internal/store/store.go 6
}
@test "GO-006 passes on %w, commented ignores and strings" {
  passes 006-pass
}
@test "GO-006 honours archgate-ignore with a reason" {
  passes 006-pass-allow
}

# GO-007
@test "GO-007 fails on a port method without context" {
  use 007-fail
  run archgate check
  violation port-methods-take-context internal/ports/repo.go 7
}
@test "GO-007 fails on a multi-line signature without context" {
  use 007-fail-multiline
  run archgate check
  violation port-methods-take-context internal/ports/repo.go 4
}
@test "GO-007 passes with context first, embedded interfaces and non-port interfaces" {
  passes 007-pass
}

# GO-008
@test "GO-008 fails on func main outside cmd" {
  use 008-fail-main
  run archgate check
  violation composition-root-in-cmd main.go 3
}
@test "GO-008 fails on adapter wiring outside cmd" {
  use 008-fail-import
  run archgate check
  violation composition-root-in-cmd internal/server/server.go 3
}
@test "GO-008 passes on wiring in cmd" {
  passes 008-pass
}
@test "GO-008 honours archgate-ignore with a reason" {
  passes 008-pass-allow
}

# False-positive guards
@test "the hex-sample fixture passes every ADR" {
  passes hex-sample
}
@test "the go-sample fixture passes every ADR" {
  cp -r "$BATS_TEST_DIRNAME/fixtures/go-sample/." "$REPO/"
  run archgate check
  [ "$status" -eq 0 ]
}

@test "Go ADRs stay out of a Python-only change even if the files are present" {
  mkdir src
  echo 'x = 1' >src/app.py
  git add -A && git -c user.name=t -c user.email=t@t commit -qm base
  echo 'y = 2' >>src/app.py
  run archgate check
  [ "$status" -eq 0 ]
  run archgate review-context
  [[ "$output" == *"GEN-001"* ]]
  [[ "$output" != *'"id":"GO-'* ]]
}
