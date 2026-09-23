---
name: typescript-conventions
description: Jig conventions for writing TypeScript/JavaScript code (tooling, typing, modules, tests, errors). Loaded automatically when working on TS/JS files.
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.mts"
  - "**/*.cts"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.mjs"
  - "**/*.cjs"
  - "**/package.json"
  - "**/tsconfig*.json"
user-invocable: false
---

# TypeScript conventions (Jig)

Company-wide defaults. A repo's own `.claude/rules/` files or ADRs in `.archgate/adrs/` override them.

**Tooling.** Use the repo's package manager (the lockfile tells you: `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`, else npm). Add dependencies with it (`pnpm add -D ...`), never by hand-editing the lockfile. Don't run installs unless the user asks. The formatter/linter is whatever the repo configures: biome (`biome.json`) or eslint (+ prettier if the repo uses it). The hooks run it after every edit and `tsc --noEmit` + the tests when you stop, so fix what they report instead of silencing it.

**Typing.** `strict` on. Type exported function signatures and return values. No `any`: use `unknown` and narrow, or a precise type. No non-null `!` or `as` casts to silence errors. Prefer `type` unions and `as const` over enums. `// @ts-expect-error`, `// biome-ignore` or `// eslint-disable-next-line` only with a reason, and only if the user agrees. Never `@ts-ignore`.

**Modules.** ES modules, named exports (no default exports outside framework conventions). Import types with `import type`. No side effects at import time. Keep the repo's module style (`.js` suffixes in relative imports under `NodeNext`).

**Errors.** Throw `Error` subclasses, never strings. Don't swallow errors (`catch {}`); handle, wrap with `{ cause }`, or rethrow. Always `await` or return promises (no floating promises).

**Tests.** The repo's runner (vitest by default), next to the code (`*.test.ts`) or in `test/`. A bug fix starts with a failing test. Don't weaken, skip (`.skip`/`.only`) or delete a failing test to make the Stop hook pass.

**Security.** No secrets in code or tests. Validate external input at the boundary (e.g. zod). No `eval`/`new Function`; use `execFile`/`spawn` with argument arrays, not shell strings.

**Finding things.** Use the LSP (go to definition, find references, hover types) before grepping.
