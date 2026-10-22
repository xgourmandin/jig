---
id: TS-008
title: No import-time I/O in the inner layers
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

# No import-time I/O in the inner layers

## Context

Code that runs when a module is imported (network calls, file reads, logging, timers, top-level await) makes tests slow and order-dependent and makes the core impossible to load without its infrastructure.

## Decision

In `src/domain/`, `src/application/` and `src/ports/`, a statement at the top level of a module (column 0 of formatted code) must not call `fetch`, `console.*`, `fs.*`, `readFileSync`/`writeFileSync`, `axios.*`, `spawn`/`exec*`, `setTimeout`/`setInterval`, `process.exit`, `dotenv.config`, construct clients (`new PrismaClient(`, `new Pool(`, `new Redis(`, ...), or use top-level `await`. I/O belongs in functions called from bootstrap or main. Code nested in blocks is not scanned (the check assumes formatted code).

Layout assumed: `src/{domain,application,ports,adapters/<name>,bootstrap,main}/` plus the frontend directories `src/{components,pages,routes,views,features,hooks,composables,stores,ui}/` (the "ui" layer; the full layout, how a feature-folder frontend maps onto it, the scanned file types and the alias rules are described in TS-001). Any other file under `src/` is "other"; files outside `src/` and test files are not layer-checked.

Opt out for one statement with `// archgate-ignore TS-008/no-import-time-io <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- `export function createClock() { return { now: () => new Date() } }`

### Don't

- `const rates = await fetch("https://...")` at the top of a domain module
- `console.log("loaded")` at module level

## Consequences

Importing the core has no side effects. Rule `no-import-time-io` in `TS-008-no-import-time-io-in-inner-layers.rules.ts`.
