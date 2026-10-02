---
id: TS-010
title: Types and style are enforced by tsc and biome or eslint
domain: typescript
rules: false
files: ["**/*.ts", "**/*.tsx", "**/*.mts", "**/*.cts", "**/*.js", "**/*.jsx", "**/*.mjs", "**/*.cjs", "**/*.vue", "**/*.svelte", "**/*.astro", "**/tsconfig*.json"]
---

# Types and style are enforced by tsc and biome or eslint

## Context
Type safety, formatting, import order, unused code and many bug patterns are mechanical, and tsc, biome and eslint already check them. Re-implementing them as Archgate rules would duplicate maintained tools. The path-based checks of TS-001..TS-009 and TS-011 are also approximations that a dependency analyser does better.

## Decision
This ADR is documentation only (no `.rules.ts`). Every TypeScript project configures:
- `tsconfig.json` with `"strict": true` plus `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitOverride` and `verbatimModuleSyntax` for new code (legacy code may start with a subset and ratchet up); `tsc --noEmit` runs in `mise run lint`.
- Biome (`biome check`), or ESLint with `typescript-eslint` (`strictTypeChecked`) plus Prettier, enabling at least `no-explicit-any`, `no-floating-promises`, `consistent-type-imports`, `no-unused-vars` and `eqeqeq`.
- Architecture linting that mirrors TS-001..TS-005 and TS-011 with real module resolution, either [dependency-cruiser](https://github.com/sverweij/dependency-cruiser) (`forbidden` rules per layer, `no-circular`) or `eslint-plugin-boundaries` / `import/no-restricted-paths`. Use it when the repo needs `extends`ed tsconfig `paths`, framework-generated aliases, a non-`src/` layout, layering inside feature folders, a server/client split (Next/Nuxt/SvelteKit) or package-boundary rules in a monorepo.
- Frontend projects (React, Vue, Svelte, Next/Nuxt, Vite) additionally: the framework's lint plugins (`eslint-plugin-react-hooks`, `eslint-plugin-vue` with `vue-tsc --noEmit`, `eslint-plugin-svelte` with `svelte-check`, `astro check`), a boundaries rule that keeps the ui layer off `adapters/`, accessibility linting (`jsx-a11y`, `vuejs-accessibility`), and tests with vitest (or jest) plus Testing Library (`@testing-library/react|vue|svelte`) that render components against fake adapters or ports.

The jig-typescript plugin already runs biome/eslint on edit and tsc plus tests on Stop; this ADR makes the configuration part of the repo.

## Do's and Don'ts
### Do
- Fix type errors rather than casting; add a dependency-cruiser rule when the domain must never import a new framework
### Don't
- Turn off `strict` globally to silence errors, or silence a linter with a blanket `eslint-disable` instead of fixing the code or recording an exception with a reason

## Consequences
Two independent checks for the architecture boundaries, so a gap in one rarely lets a violation through; CI and the agent run the same checks through `mise run lint`.
