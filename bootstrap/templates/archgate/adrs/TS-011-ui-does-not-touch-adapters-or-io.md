---
id: TS-011
title: The ui layer uses the application, not adapters or I/O clients
domain: typescript
rules: true
files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts", "**/*.js", "**/*.jsx", "**/*.mjs", "**/*.cjs", "**/*.vue", "**/*.svelte", "**/*.astro"]
---

# The ui layer uses the application, not adapters or I/O clients

## Context
In a frontend, components that call `fetch`, an HTTP client or a Firebase SDK directly are hard to test, hard to reuse and tie the screen to one backend. The same hexagonal rule applies: the ui is a driving side of the application, and infrastructure is injected.

## Decision
Files in the ui layer (`src/{components,pages,routes,views,features,hooks,composables,stores,ui}/`, including `.vue`, `.svelte` and `.astro` script blocks) must not:
- import `src/adapters/**`, `src/bootstrap/**` or `src/main` (relative paths, tsconfig `paths` and the `@/`, `~/`, `#/`, `src/` aliases are resolved, see TS-001);
- import an I/O client or Node I/O built-in (axios, ky, ofetch, got, firebase, `@supabase/*`, `@apollo/client`, urql, graphql-request, `@trpc/client`, socket.io-client, prisma, `@aws-sdk/*`, `node:fs`, ...);
- call `fetch(...)`, `window.fetch(...)`, `$fetch(...)` or construct `XMLHttpRequest`, `WebSocket` or `EventSource` directly.

The ui reaches infrastructure through application hooks or services, a context/provider (React), `provide`/`inject` or a plugin (Vue), a store, or props, all wired in `src/bootstrap` / `src/main` (for example `<OrdersProvider value={container.orders}>`). Data-fetching libraries without their own client (`@tanstack/react-query`, SWR, Pinia) are fine in the ui as long as the query function comes from the application layer.

Layout and file types are those of TS-001. Limits: the check is by path, so a Next `src/pages/api/**` or Nuxt `server/` handler (server code under a ui directory name) is seen as ui: add `// archgate-ignore TS-011/ui-uses-application-not-adapters <reason>` on the line before the statement or keep server handlers outside those directories. Template expressions in `.vue`/`.svelte`/markup are not scanned.

Opt out for one statement with `// archgate-ignore TS-011/ui-uses-application-not-adapters <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- `const orders = useOrders();` where `useOrders` is an application hook reading the injected port
- Build the HTTP client in `src/adapters/http/` and pass it in from `src/bootstrap/`
### Don't
- `import axios from "axios"` or `fetch("/api/orders")` in a component, page or store
- `import { PgOrders } from "../../adapters/postgres/orders"` in a hook

## Consequences
Components render against fake ports in vitest + Testing Library, and the backend can change without touching screens. Rule `ui-uses-application-not-adapters` in `TS-011-ui-does-not-touch-adapters-or-io.rules.ts`.
