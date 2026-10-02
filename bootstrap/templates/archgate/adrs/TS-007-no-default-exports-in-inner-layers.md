---
id: TS-007
title: No default exports in domain and application
domain: typescript
rules: true
files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts", "**/*.js", "**/*.jsx", "**/*.mjs", "**/*.cjs", "**/*.vue", "**/*.svelte", "**/*.astro"]
---

# No default exports in domain and application

## Context
Default exports let every importer pick its own name, which breaks search, rename refactors and the "one concept, one name" language of the domain.

## Decision
Modules in `src/domain/` and `src/application/` use named exports only: no `export default ...` and no `export { x as default }`. Adapters, bootstrap, main and framework-mandated files (config files, Next.js pages) may keep default exports.

Layout assumed: `src/{domain,application,ports,adapters/<name>,bootstrap,main}/` plus the frontend directories `src/{components,pages,routes,views,features,hooks,composables,stores,ui}/` (the "ui" layer; the full layout, how a feature-folder frontend maps onto it, the scanned file types and the alias rules are described in TS-001). Any other file under `src/` is "other"; files outside `src/` and test files are not layer-checked.

Opt out for one export with `// archgate-ignore TS-007/no-default-exports-in-inner-layers <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- `export class Order { ... }`
### Don't
- `export default class Order { ... }`

## Consequences
Imports of core concepts use one name everywhere. Rule `no-default-exports-in-inner-layers` in `TS-007-no-default-exports-in-inner-layers.rules.ts`.
