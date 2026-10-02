---
id: TS-006
title: No any and no unexplained ts-ignore
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

# No any and no unexplained ts-ignore

## Context

`any` and `@ts-ignore` switch the type checker off exactly where it is needed, and the damage spreads through inferred types.

## Decision

In non-test code:

- no `any` in type positions (`: any`, `as any`, `<any>`, `any[]`, `Record<string, any>`, ...): use `unknown` and narrow, or a precise type. TypeScript files only; `.d.ts` files are skipped;
- no `// @ts-ignore` and no `// @ts-nocheck`;
- `// @ts-expect-error` is allowed only with a description (`// @ts-expect-error: legacy typings, see SHOP-12`), so it fails loudly once the error goes away.

Opt out for one occurrence with `// archgate-ignore TS-006/no-any-or-unexplained-ts-ignore <reason>` on the line before it. The reason is required, without one the violation stays. Comments and strings are masked, so the word "any" in prose is fine.

## Do's and Don'ts

### Do

- `function parse(input: unknown): Order` with a type guard or schema (zod, valibot)

### Don't

- `const data = res.json() as any`
- `// @ts-ignore`

## Consequences

Type holes stay visible and justified. Complements the strict tsconfig in TS-010. Rule `no-any-or-unexplained-ts-ignore` in `TS-006-no-any-or-unexplained-ts-ignore.rules.ts`.
