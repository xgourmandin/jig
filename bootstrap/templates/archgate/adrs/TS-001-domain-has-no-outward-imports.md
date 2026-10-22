---
id: TS-001
title: The domain imports nothing outward
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

# The domain imports nothing outward

## Context

Hexagonal architecture keeps business rules free of frameworks and infrastructure so they can be tested without a database or web server and survive a framework swap.

## Decision

Modules in `src/domain/` import only other domain modules, the language runtime and pure libraries (for example `zod`, `date-fns`). They never import web/ORM/HTTP/cloud/queue clients (list in the rule file: express, fastify, `@nestjs/*`, prisma, typeorm, axios, firebase, `@aws-sdk/*`, ...), Node I/O built-ins (`node:fs`, `node:http`, `node:net`, `node:child_process`, ... with or without the `node:` prefix), UI frameworks, routers and state/data libraries (react, react-dom, vue, svelte, `@angular/*`, solid-js, preact, react-router, vue-router, `@tanstack/*`, redux, `@reduxjs/*`, zustand, pinia, mobx, jotai, recoil, swr, ...), `next/*` and `nuxt` (the server/client split of a Next/Nuxt app is not modelled: they are forbidden here and in application/ports, and not checked in the ui layer), nor the application, ports, adapters, ui, bootstrap or main layers. `rxjs` is allowed (a pure library). The domain also uses no browser globals: `window`, `document`, `localStorage`, `sessionStorage`, `navigator`, `location` (comments and strings are ignored; `window`/`document` need a member access or `typeof`, `navigator`/`location` a browser member such as `location.href`, and a name the file declares itself is skipped). Type-only imports count too.

Opt out for one import with a comment `// archgate-ignore TS-001/domain-imports-nothing-outward <reason>` on the line before it. The reason is required, without one the violation stays.

## Layout, file types and aliases

Layout assumed (backend and frontend):

```
src/
  domain/ application/ ports/          inner layers: pure TypeScript
  adapters/<name>/                     HTTP/DB/storage/SDK clients, one folder per adapter
  bootstrap/  main(.ts|/)              composition root: builds adapters, injects them
  components/ pages/ routes/ views/ features/ hooks/ composables/ stores/ ui/   "ui" layer
  <anything else>                      "other" (config.ts, App.tsx, util/, ...): only TS-005/006/009 look at it
```

Dependencies point inward: ui -> application -> domain, ports; adapters -> ports, domain; bootstrap/main -> everything. The ui layer may import application, domain and ports (types, hooks, services) but never adapters: adapters are built in bootstrap/main and reach components through application hooks or services, a context/provider (React), `provide`/`inject` or a plugin (Vue), a store, or props. A feature-folder frontend (`src/features/<name>/{components,hooks,api,...}`) maps like this: everything under `src/features/**`, `src/components/**` etc. is the ui layer; business rules go to `src/domain/<feature>` and use cases to `src/application/<feature>`; the feature's network code goes to `src/adapters/<feature>` behind a port in `src/ports`. Layering inside a feature folder (a `domain/` under `features/<name>/`) is not modelled: it counts as ui. In a monorepo each package has its own `src/`.

Files: `.ts .tsx .mts .cts .js .jsx .mjs .cjs`, plus the `<script>` / `<script setup>` blocks (any `lang`) of `.vue` and `.svelte` files and the frontmatter and `<script>` tags of `.astro` files; the rest of those files is ignored (line numbers are kept; markup, `<style>` and template expressions are not checked, so a `fetch` in a Vue template is not seen). Test files (`*.test.*`, `*.spec.*`, `__tests__/`) and `.d.ts` files are not layer-checked. Imports are found in code: `import`, `import type`, `export ... from`, `require()` and dynamic `import()`.

Aliases: relative paths and the `compilerOptions.paths` (with `baseUrl`) of the nearest `tsconfig.json` or `tsconfig.app.json` that defines them are resolved; if none matches, the built-in `@/`, `~/`, `#/` and `src/` (all meaning the src root) are used. `extends` is not followed (repeat `paths` in the package's own tsconfig), only the first target of a `paths` entry is used, and framework-generated aliases (Nuxt `~`/`@` and `#imports`, SvelteKit `$lib`, Astro, Vite `resolve.alias` without a tsconfig entry) are not known: keep them in tsconfig `paths`, or use relative imports.

## Do's and Don'ts

### Do

- `import { Money } from "./money.js"` inside the domain
- Express what the domain needs from the outside as a port

### Don't

- `import express from "express"`, `import { readFileSync } from "node:fs"` or `import { useState } from "react"` in the domain
- `window.localStorage` or `document.cookie` in the domain; define a storage/cookie port
- `import { PgOrders } from "../adapters/postgres/orders.js"` in the domain

## Consequences

Domain tests run with no infrastructure. Rule `domain-imports-nothing-outward` in `TS-001-domain-has-no-outward-imports.rules.ts`.
