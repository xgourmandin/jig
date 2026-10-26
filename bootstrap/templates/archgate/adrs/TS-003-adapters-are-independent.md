---
id: TS-003
title: Adapters are independent of each other
domain: typescript
rules: true
files:
  [
    "**/*.ts",
    "**/*.tsx",
    "**/*.mts",
    "**/*.cts",
    "**/*.js",
    "**/*.jsx",
    "**/*.mjs",
    "**/*.cjs",
    "**/*.vue",
    "**/*.svelte",
    "**/*.astro",
  ]
---

# Adapters are independent of each other

## Context

Adapters are interchangeable plug-ins. Once one adapter imports another, they cannot be replaced or tested separately, and a hidden dependency graph grows at the edge.

## Decision

A module in `src/adapters/<name>/` never imports a module of another `src/adapters/<other>/`, nor `src/bootstrap` or `src/main`. Share behaviour through a port or the domain. Adapters may import the domain, ports, application types, frameworks and their own files. A barrel `adapters/index.ts` is not treated as an adapter.

Layout assumed: `src/{domain,application,ports,adapters/<name>,bootstrap,main}/` plus the frontend directories `src/{components,pages,routes,views,features,hooks,composables,stores,ui}/` (the "ui" layer; the full layout, how a feature-folder frontend maps onto it, the scanned file types and the alias rules are described in TS-001). Any other file under `src/` is "other"; files outside `src/` and test files are not layer-checked.

Opt out for one import with `// archgate-ignore TS-003/adapters-do-not-import-each-other <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- Let `adapters/http` call the use case, which uses the `OrderRepository` port implemented by `adapters/postgres`

### Don't

- `import { PgOrders } from "../postgres/orders.js"` in `adapters/http`

## Consequences

Each adapter can be deleted or swapped on its own. Rule `adapters-do-not-import-each-other` in `TS-003-adapters-are-independent.rules.ts`.
