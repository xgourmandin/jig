---
id: TS-002
title: Application and ports depend inward only
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

# Application and ports depend inward only

## Context

Use cases orchestrate the domain through ports. If they reach for an adapter or a framework directly, the dependency direction inverts and the use case can no longer be tested with a fake.

## Decision

Modules in `src/application/` and `src/ports/` import only the domain, ports, other application modules and pure libraries. They never import adapters, ui, bootstrap or main, nor frameworks, UI libraries, state/data libraries, infrastructure clients or Node I/O built-ins (same list as TS-001: react, vue, svelte, redux, zustand, pinia, `@tanstack/*`, ...), and use no browser globals (`window`, `document`, `localStorage`, `sessionStorage`, `navigator`, `location`). Frontend use cases are plain functions/classes that hooks, stores and components call; keep React hooks, Pinia stores and the like in the ui layer and have them call the use case.

Layout assumed: `src/{domain,application,ports,adapters/<name>,bootstrap,main}/` plus the frontend directories `src/{components,pages,routes,views,features,hooks,composables,stores,ui}/` (the "ui" layer; the full layout, how a feature-folder frontend maps onto it, the scanned file types and the alias rules are described in TS-001). Any other file under `src/` is "other"; files outside `src/` and test files are not layer-checked.

Opt out for one import with `// archgate-ignore TS-002/application-depends-inward-only <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- Take a `OrderRepository` port in the use case constructor; the composition root passes the adapter

### Don't

- `import { PgOrders } from "../adapters/postgres/orders.js"` in a use case
- `import axios from "axios"` in a port file

## Consequences

Use cases are tested with in-memory fakes. Rule `application-depends-inward-only` in `TS-002-application-depends-on-domain-and-ports.rules.ts`.
