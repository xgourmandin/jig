#!/usr/bin/env bats
# Run: bats tests/   (needs archgate from `mise install`)
# Each TypeScript ADR rule must fail on a bad fixture and pass on a good one.
# Fixtures: tests/fixtures/ts-adr/<id>-<fail|pass>[-variant]/  (layout: src/<layer>/)
TEMPLATES="$BATS_TEST_DIRNAME/../bootstrap/templates/archgate"
FIXTURES="$BATS_TEST_DIRNAME/fixtures/ts-adr"

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

# fails <fixture> <rule> <file> <line>
fails() {
  use "$1"
  run archgate check
  violation "$2" "$3" "$4"
}

passes() {
  use "$1"
  run archgate check
  [ "$status" -eq 0 ]
}

@test "helper block is identical in every TS rule file" {
  cd "$TEMPLATES/adrs"
  ref=""
  n=0
  for f in TS-0*.rules.ts; do
    block="$(sed -n '/<jig-ts-helpers>/,/<\/jig-ts-helpers>/p' "$f")"
    [ -n "$block" ]
    [ -z "$ref" ] && ref="$block"
    [ "$block" = "$ref" ] || { echo "$f differs"; return 1; }
    n=$((n + 1))
  done
  [ "$n" -ge 10 ]
}

@test "all TS ADRs parse" {
  run archgate adr list
  [ "$status" -eq 0 ]
  for id in TS-001 TS-002 TS-003 TS-004 TS-005 TS-006 TS-007 TS-008 TS-009 TS-010 TS-011; do [[ "$output" == *"$id"* ]]; done
}

# TS-001
@test "TS-001 fails on a framework import in the domain" {
  fails 001-fail-framework domain-imports-nothing-outward src/domain/order.ts 1
}
@test "TS-001 fails on a node:fs import in the domain" {
  fails 001-fail-node domain-imports-nothing-outward src/domain/order.ts 1
}
@test "TS-001 fails on a bare https import in the domain" {
  fails 001-fail-node-bare domain-imports-nothing-outward src/domain/order.ts 1
}
@test "TS-001 fails on a relative adapter import in the domain" {
  fails 001-fail-adapter domain-imports-nothing-outward src/domain/order.ts 3
}
@test "TS-001 fails on an aliased application import in the domain" {
  fails 001-fail-alias domain-imports-nothing-outward src/domain/order.ts 1
}
@test "TS-001 fails on an import type of the application layer" {
  fails 001-fail-application domain-imports-nothing-outward src/domain/order.ts 1
}
@test "TS-001 fails on require() of a node built-in" {
  fails 001-fail-require domain-imports-nothing-outward src/domain/order.js 1
}
@test "TS-001 fails on a dynamic import of a framework" {
  fails 001-fail-dynamic domain-imports-nothing-outward src/domain/order.ts 2
}
@test "TS-001 fails on export * from an adapter" {
  fails 001-fail-reexport domain-imports-nothing-outward src/domain/index.ts 1
}
@test "TS-001 reports a multi-line import at its first line" {
  fails 001-fail-multiline domain-imports-nothing-outward src/domain/order.ts 1
}
@test "TS-001 still sees imports after regex literals, division and nested templates" {
  fails 001-fail-after-tricky domain-imports-nothing-outward src/domain/order.ts 5
}
@test "TS-001 rejects archgate-ignore without a reason" {
  fails 001-fail-allow-no-reason domain-imports-nothing-outward src/domain/order.ts 2
  [[ "$output" == *"missing a reason"* ]]
}
@test "TS-001 passes on node:crypto, domain imports, comments, strings and templates" {
  passes 001-pass
}
@test "TS-001 honours archgate-ignore with a reason" {
  passes 001-pass-allow
}
@test "TS-001 fails on a react import in the domain" {
  fails 001-fail-react domain-imports-nothing-outward src/domain/cart.ts 1
}
@test "TS-001 fails on a @tanstack import in the domain" {
  fails 001-fail-router domain-imports-nothing-outward src/domain/cart.ts 2
}
@test "TS-001 fails on next/navigation in the domain" {
  fails 001-fail-next domain-imports-nothing-outward src/domain/cart.ts 1
}
@test "TS-001 fails on a pinia import in the domain" {
  fails 001-fail-pinia domain-imports-nothing-outward src/domain/cart.ts 1
}
@test "TS-001 fails when the domain imports the ui layer" {
  fails 001-fail-ui-layer domain-imports-nothing-outward src/domain/cart.ts 1
}
@test "TS-001 fails on window.localStorage in the domain" {
  fails 001-fail-window domain-imports-nothing-outward src/domain/cart.ts 3
}
@test "TS-001 fails on a bare localStorage use in the domain" {
  fails 001-fail-localstorage domain-imports-nothing-outward src/domain/cart.ts 2
}
@test "TS-001 fails on a column-0 document.getElementById in the domain" {
  fails 001-fail-document domain-imports-nothing-outward src/domain/cart.ts 1
}
@test "TS-001 fails on location.href in the domain" {
  fails 001-fail-location domain-imports-nothing-outward src/domain/cart.ts 2
}
@test "TS-001 resolves a tsconfig paths wildcard alias (with comments and trailing commas)" {
  fails 001-fail-paths domain-imports-nothing-outward src/domain/cart.ts 2
}
@test "TS-001 resolves an exact tsconfig paths alias" {
  fails 001-fail-paths-exact domain-imports-nothing-outward src/domain/cart.ts 1
}
@test "TS-001 resolves a bare layer import through baseUrl" {
  fails 001-fail-baseurl domain-imports-nothing-outward src/domain/cart.ts 1
}
@test "TS-001 uses the nearest tsconfig in a monorepo package" {
  fails 001-fail-nested-tsconfig domain-imports-nothing-outward packages/web/src/domain/cart.ts 1
}
@test "TS-001 passes on rxjs, aliases leaving src, and browser words in strings, fields and parameters" {
  passes 001-pass-browser-words
}
# TS-002
@test "TS-002 fails when the application imports an adapter" {
  fails 002-fail-adapter application-depends-inward-only src/application/place-order.ts 2
}
@test "TS-002 fails on an aliased adapters import in the application" {
  fails 002-fail-alias application-depends-inward-only src/application/place-order.ts 1
}
@test "TS-002 fails on a framework import in ports" {
  fails 002-fail-framework application-depends-inward-only src/ports/orders.ts 2
}
@test "TS-002 fails when the application imports bootstrap" {
  fails 002-fail-bootstrap application-depends-inward-only src/application/place-order.ts 1
}
@test "TS-002 fails when the application imports main" {
  fails 002-fail-main application-depends-inward-only src/application/place-order.ts 1
}
@test "TS-002 passes on domain/ports imports and wiring in bootstrap" {
  passes 002-pass
}
@test "TS-002 fails when the application imports the ui layer" {
  fails 002-fail-ui application-depends-inward-only src/application/place-order.ts 2
}
@test "TS-002 fails on a react import in the application" {
  fails 002-fail-react application-depends-inward-only src/application/place-order.ts 1
}
@test "TS-002 fails on a redux toolkit import in ports" {
  fails 002-fail-redux application-depends-inward-only src/ports/orders.ts 2
}
@test "TS-002 fails on sessionStorage in the application" {
  fails 002-fail-sessionstorage application-depends-inward-only src/application/place-order.ts 2
}
@test "TS-002 fails on typeof window in ports" {
  fails 002-fail-window application-depends-inward-only src/ports/orders.ts 2
}
# TS-003
@test "TS-003 fails when an adapter imports another adapter" {
  fails 003-fail-cross adapters-do-not-import-each-other src/adapters/postgres/orders.ts 2
}
@test "TS-003 fails on an aliased import of a sibling adapter" {
  fails 003-fail-alias adapters-do-not-import-each-other src/adapters/postgres/orders.ts 1
}
@test "TS-003 fails when an adapter imports bootstrap" {
  fails 003-fail-bootstrap adapters-do-not-import-each-other src/adapters/postgres/orders.ts 1
}
@test "TS-003 fails on a side-effect import of main" {
  fails 003-fail-main adapters-do-not-import-each-other src/adapters/http/routes.ts 1
}
@test "TS-003 passes on inward imports, frameworks and the adapter's own modules" {
  passes 003-pass
}
@test "TS-003 resolves tsconfig paths to a sibling adapter" {
  fails 003-fail-paths adapters-do-not-import-each-other src/adapters/http/routes.ts 1
}
# TS-004
@test "TS-004 fails on an abstract class defined in an adapter" {
  fails 004-fail-adapter ports-defined-inside-not-in-adapters src/adapters/postgres/base.ts 3
}
@test "TS-004 fails on a *Gateway interface defined in an adapter" {
  fails 004-fail-adapter-interface ports-defined-inside-not-in-adapters src/adapters/http/client.ts 2
}
@test "TS-004 fails on a concrete *Repository class in ports" {
  fails 004-fail-port-concrete ports-defined-inside-not-in-adapters src/ports/orders.ts 1
}
@test "TS-004 passes on interfaces in ports and adapters implementing them" {
  passes 004-pass
}
# TS-005
@test "TS-005 fails on adapter wiring in src/server.ts" {
  fails 005-fail-import composition-root-in-bootstrap src/server.ts 1
}
@test "TS-005 fails on adapter wiring in a wiring module" {
  fails 005-fail-wiring composition-root-in-bootstrap src/wiring/wire.ts 2
}
@test "TS-005 fails on an aliased re-export of an adapter from src/index.ts" {
  fails 005-fail-alias composition-root-in-bootstrap src/index.ts 1
}
@test "TS-005 passes on wiring in bootstrap and main" {
  passes 005-pass
}
@test "TS-005 honours archgate-ignore with a reason" {
  passes 005-pass-allow
}
@test "TS-005 fails on adapter wiring in a Vue SFC script" {
  fails 005-fail-vue composition-root-in-bootstrap src/App.vue 6
}
@test "TS-005 resolves a bare adapters import through baseUrl" {
  fails 005-fail-baseurl composition-root-in-bootstrap src/server.ts 1
}
# TS-006
@test "TS-006 fails on any in a parameter" {
  fails 006-fail-any no-any-or-unexplained-ts-ignore src/util.ts 1
}
@test "TS-006 fails on as any" {
  fails 006-fail-any no-any-or-unexplained-ts-ignore src/util.ts 5
}
@test "TS-006 fails on any as a generic argument" {
  fails 006-fail-any-generic no-any-or-unexplained-ts-ignore src/util.ts 1
}
@test "TS-006 fails on @ts-ignore" {
  fails 006-fail-ignore no-any-or-unexplained-ts-ignore src/util.ts 2
}
@test "TS-006 fails on @ts-expect-error without a description" {
  fails 006-fail-expect-nodesc no-any-or-unexplained-ts-ignore src/util.ts 2
}
@test "TS-006 fails on @ts-nocheck in a JS file" {
  fails 006-fail-nocheck no-any-or-unexplained-ts-ignore src/util.js 1
}
@test "TS-006 rejects archgate-ignore without a reason" {
  fails 006-fail-allow-no-reason no-any-or-unexplained-ts-ignore src/util.ts 2
}
@test "TS-006 passes on unknown, described @ts-expect-error, prose, strings, .d.ts and archgate-ignore" {
  passes 006-pass
}
@test "TS-006 fails on any in a lang=ts Vue script" {
  fails 006-fail-vue-any no-any-or-unexplained-ts-ignore src/App.vue 3
}
@test "TS-006 ignores any-looking text in a JS Vue component" {
  passes 006-pass-vue-js
}
# TS-007
@test "TS-007 fails on export default in the domain" {
  fails 007-fail-domain no-default-exports-in-inner-layers src/domain/order.ts 1
}
@test "TS-007 fails on export { x as default } in the application" {
  fails 007-fail-named-default no-default-exports-in-inner-layers src/application/x.ts 2
}
@test "TS-007 passes on named exports and default exports in adapters/bootstrap" {
  passes 007-pass
}
@test "TS-007 honours archgate-ignore with a reason" {
  passes 007-pass-allow
}
# TS-008
@test "TS-008 fails on a top-level fetch in the domain" {
  fails 008-fail-fetch no-import-time-io src/domain/rates.ts 2
}
@test "TS-008 fails on console.log at import time in the application" {
  fails 008-fail-console no-import-time-io src/application/log.ts 2
}
@test "TS-008 fails on fs.readFileSync at import time in ports" {
  fails 008-fail-fs no-import-time-io src/ports/p.ts 1
}
@test "TS-008 fails on a client constructed at import time" {
  fails 008-fail-client no-import-time-io src/domain/db.ts 1
}
@test "TS-008 fails on top-level await" {
  fails 008-fail-await no-import-time-io src/domain/cfg.ts 3
}
@test "TS-008 passes on I/O inside functions and in adapters/bootstrap" {
  passes 008-pass
}
@test "TS-008 honours archgate-ignore with a reason" {
  passes 008-pass-allow
}
# TS-009
@test "TS-009 fails on process.env in the domain" {
  fails 009-fail-domain no-process-env-outside-bootstrap src/domain/cfg.ts 1
}
@test "TS-009 fails on import.meta.env in an unnamed layer" {
  fails 009-fail-other no-process-env-outside-bootstrap src/util.ts 2
}
@test "TS-009 fails on process.env[...] in the application" {
  fails 009-fail-application no-process-env-outside-bootstrap src/application/x.ts 2
}
@test "TS-009 passes in adapters, bootstrap, main, prose and scripts" {
  passes 009-pass
}
@test "TS-009 honours archgate-ignore with a reason" {
  passes 009-pass-allow
}

@test "TS-009 fails on import.meta.env in a component" {
  fails 009-fail-component no-process-env-outside-bootstrap src/components/Banner.tsx 2
}
@test "TS-009 fails on process.env in a Vue SFC script" {
  fails 009-fail-vue no-process-env-outside-bootstrap src/views/Home.vue 3
}
@test "TS-009 does not exempt a config.ts inside a ui directory" {
  fails 009-fail-ui-config no-process-env-outside-bootstrap src/components/config.ts 2
}
@test "TS-009 allows config.ts, env.ts, env.client.ts and config/ modules" {
  passes 009-pass-config
}
# TS-011
@test "TS-011 fails when a component imports an adapter" {
  fails 011-fail-adapter ui-uses-application-not-adapters src/components/Cart.tsx 2
}
@test "TS-011 fails on an aliased adapter import in a hook" {
  fails 011-fail-alias ui-uses-application-not-adapters src/hooks/use-cart.ts 1
}
@test "TS-011 resolves tsconfig paths to adapters (trailing commas)" {
  fails 011-fail-paths ui-uses-application-not-adapters src/stores/cart.ts 1
}
@test "TS-011 fails when a page imports bootstrap" {
  fails 011-fail-bootstrap ui-uses-application-not-adapters src/pages/Home.tsx 1
}
@test "TS-011 fails on axios in a feature" {
  fails 011-fail-axios ui-uses-application-not-adapters src/features/cart/api.ts 2
}
@test "TS-011 fails on firebase in a composable" {
  fails 011-fail-firebase ui-uses-application-not-adapters src/composables/useAuth.ts 1
}
@test "TS-011 fails on a global fetch in a component" {
  fails 011-fail-fetch ui-uses-application-not-adapters src/components/Cart.tsx 4
}
@test "TS-011 fails on window.fetch in a view" {
  fails 011-fail-window-fetch ui-uses-application-not-adapters src/views/Home.ts 2
}
@test "TS-011 fails on new WebSocket in a store" {
  fails 011-fail-websocket ui-uses-application-not-adapters src/stores/live.ts 2
}
@test "TS-011 fails on axios in a Vue SFC script setup" {
  fails 011-fail-vue ui-uses-application-not-adapters src/views/Cart.vue 6
}
@test "TS-011 fails on fetch in a plain Vue script" {
  fails 011-fail-vue-fetch ui-uses-application-not-adapters src/components/Cart.vue 4
}
@test "TS-011 fails on an adapter import in a Svelte script" {
  fails 011-fail-svelte ui-uses-application-not-adapters src/components/Cart.svelte 2
}
@test "TS-011 fails on an adapter import in Astro frontmatter" {
  fails 011-fail-astro ui-uses-application-not-adapters src/pages/index.astro 2
}
@test "TS-011 rejects archgate-ignore without a reason" {
  fails 011-fail-allow-no-reason ui-uses-application-not-adapters src/components/Cart.tsx 3
  [[ "$output" == *"missing a reason"* ]]
}
@test "TS-011 passes on application hooks, ports, domain types, methods named fetch and adapters that fetch" {
  passes 011-pass
}
@test "TS-011 honours archgate-ignore with a reason" {
  passes 011-pass-allow
}

# False-positive guard
@test "the ts-sample fixture passes every ADR" {
  passes ts-sample
}
@test "the frontend sample (React tsx, Vue SFC, Svelte, tsconfig paths) passes every ADR" {
  passes ts-frontend-sample
}

# Stack gating: ADRs are scoped by `files`, so they only show up for matching changes
@test "TS ADRs stay out of a Terraform-only change even if the files are present" {
  mkdir infra
  echo 'variable "x" {}' >infra/main.tf
  # as in a consuming repo (jig-init does this): the generated rules.d.ts is a .ts file
  echo ".archgate/rules.d.ts" >.gitignore
  git add -A && git -c user.name=t -c user.email=t@t commit -qm base
  echo '# change' >>infra/main.tf
  run archgate check
  [ "$status" -eq 0 ]
  run archgate review-context
  [[ "$output" == *"GEN-001"* ]]
  [[ "$output" != *'"id":"TS-'* ]]
}

@test "TS ADRs stay out of a Python-only change" {
  mkdir -p src/shop/domain
  echo 'x = 1' >src/shop/domain/a.py
  git add -A && git -c user.name=t -c user.email=t@t commit -qm base
  echo 'y = 2' >>src/shop/domain/a.py
  run archgate review-context
  [[ "$output" != *'"id":"TS-'* ]]
}

@test "TS ADRs apply to a TypeScript change" {
  mkdir -p src/domain
  echo 'export const x = 1;' >src/domain/a.ts
  git add -A && git -c user.name=t -c user.email=t@t commit -qm base
  echo 'export const y = 2;' >>src/domain/a.ts
  run archgate review-context
  [[ "$output" == *'"id":"TS-001"'* ]]
}
