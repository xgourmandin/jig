---
id: TS-009
title: Environment variables are read only at the edge
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

# Environment variables are read only at the edge

## Context

Reading `process.env` deep in the code hides configuration, couples logic to the deployment and makes tests mutate global state.

## Decision

`process.env`, `import.meta.env`, `Deno.env` and `Bun.env` are read only in `src/bootstrap/`, `src/main`, `src/adapters/` and a config module: `src/config.ts`, `src/env.ts` (also `config.server.ts`, `env.client.ts`, ...) or a file under a `config/` or `env/` directory outside the named layers. Domain, application, ports, ui (components, pages, hooks, stores, ...) and other files under `src/` receive configuration as arguments or import it from the config module. Framework accessors such as Nuxt `useRuntimeConfig()` or SvelteKit `$env/*` are not detected. Files outside `src/` (build configs, scripts) are not checked.

Layout assumed: `src/{domain,application,ports,adapters/<name>,bootstrap,main}/` plus the frontend directories `src/{components,pages,routes,views,features,hooks,composables,stores,ui}/` (the "ui" layer; the full layout, how a feature-folder frontend maps onto it, the scanned file types and the alias rules are described in TS-001). Any other file under `src/` is "other"; files outside `src/` and test files are not layer-checked.

Opt out for one read with `// archgate-ignore TS-009/no-process-env-outside-bootstrap <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- Parse and validate the environment once in `bootstrap/config.ts` and pass a typed `Config` down

### Don't

- `const url = process.env.DATABASE_URL` in a use case

## Consequences

All configuration is visible in one place. Rule `no-process-env-outside-bootstrap` in `TS-009-no-process-env-outside-bootstrap.rules.ts`.
