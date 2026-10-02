---
id: TS-005
title: The composition root lives in bootstrap or main
domain: typescript
rules: true
files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts", "**/*.js", "**/*.jsx", "**/*.mjs", "**/*.cjs", "**/*.vue", "**/*.svelte", "**/*.astro"]
---

# The composition root lives in bootstrap or main

## Context
Somewhere the concrete adapters must be created and handed to the use cases. If that happens in random modules, the dependency direction (TS-001..TS-003) erodes through the back door.

## Decision
Adapters are imported, constructed and injected only in `src/bootstrap/` or `src/main` (`main.ts` or `main/`). Files under `src/` outside the named layers (for example `src/index.ts`, `src/server.ts`, `src/wiring/`) must not import `src/adapters/...`. Domain, application, ports and adapters are covered by TS-001..TS-003.

Layout assumed: `src/{domain,application,ports,adapters/<name>,bootstrap,main}/` plus the frontend directories `src/{components,pages,routes,views,features,hooks,composables,stores,ui}/` (the "ui" layer; the full layout, how a feature-folder frontend maps onto it, the scanned file types and the alias rules are described in TS-001). Any other file under `src/` is "other"; files outside `src/` and test files are not layer-checked.

Opt out for one import with `// archgate-ignore TS-005/composition-root-in-bootstrap <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- `src/bootstrap/container.ts` builds `new PostgresOrderRepository(pool)` and passes it to `new PlaceOrder(repo)`; `src/main.ts` starts it
### Don't
- `src/server.ts` importing `./adapters/postgres/orders.js`

## Consequences
One place to read to see how the service is assembled. Rule `composition-root-in-bootstrap` in `TS-005-composition-root-in-bootstrap.rules.ts`.
