# jig-typescript

Enable in repos that contain TypeScript or JavaScript.

| Component | File | What it does |
|---|---|---|
| LSP | dependency `typescript-lsp@claude-plugins-official` | Official plugin, installed automatically: `typescript-language-server` definitions, references, diagnostics after each edit |
| Edit checks (PostToolUse) | `hooks/scripts/ts-post-edit.sh` | On every edited `.ts .tsx .mts .cts .js .jsx .mjs .cjs` file, the tool the repo configures: `biome check --write` (biome.json), or `prettier --write` + `eslint --fix` (eslint config); remaining errors fed back to Claude; records the file for Stop |
| Checks (Stop) | `hooks/scripts/ts-stop-check.sh` | `tsc --noEmit` for each TypeScript project edited this session (nearest `tsconfig.json`, errors only), then each package's tests (`vitest run`, else `<pm> test`); blocks once on failures |
| Tool check (SessionStart) | `hooks/scripts/check-tools.sh` | Tells Claude which binaries are missing, and when `node_modules` or the project's tsserver is missing |
| Skill | `skills/typescript-conventions` | Jig conventions, loaded automatically for TS/JS files |

**Formatter and linter, detected per repo** (nearest config wins, up to the git root):
- `biome.json`/`biome.jsonc` → `biome check --write` (format + safe fixes). Errors block, warnings don't (as in CI). biome's `files.includes` and VCS ignore settings apply.
- else an eslint config (`eslint.config.*`, `.eslintrc*`, `eslintConfig` in package.json) → `prettier --write` if the repo uses prettier (a prettier config, or prettier in package.json), then `eslint --fix`. Errors block. If eslint itself fails (broken config, missing plugin), the user gets a message and the edit is not blocked.
- else prettier only if the repo uses it; otherwise nothing. We never impose prettier's style on a repo that does not use it.

**Tests on Stop.** vitest (`vitest run --no-cache --passWithNoTests`) when the package depends on it, has a `vitest.config.*` or has it in `node_modules/.bin`; else `npm|pnpm|yarn test` / `bun run test` (package manager from the lockfile or `packageManager`) when `scripts.test` is real (not npm's "no test specified" stub). Runs with `CI=true`. Never installs packages.

**Which tools run.** Each tool comes from `node_modules/.bin` of the package or an ancestor (the version the project pins, hoisted in monorepos), then PATH (mise). The package is the nearest directory with `package.json`. Nothing is written to the repo: `tsc --noEmit` puts build info (incremental/composite projects) in the plugin data dir, vitest runs with `--no-cache`, eslint and prettier caches stay off.

**LSP needs the project's TypeScript.** `typescript-language-server` uses the tsserver from the project's `node_modules/typescript` (it does not see a mise-installed TypeScript). TypeScript 7 (the native port) ships no tsserver, so the LSP needs TypeScript 6 or earlier in the project until the official plugin moves to TS 7's own language server. `tsc` on Stop works with either.

Requires `typescript-language-server`, `jq` on PATH; `tsc`, the configured formatter/linter and the test runner in `node_modules` or on PATH (all via the repo's `mise.toml`, written by `jig-init`, and the repo's package install).
