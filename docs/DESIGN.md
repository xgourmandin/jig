# ACME Claude Code harness — design

## Goals
1. One shared, versioned harness instead of personal, non-shareable setups.
2. Adapts per project: code only, infra only, or both. Languages: Python, TypeScript, Go now; more later.
3. Deterministic tools do the checking; the model does the thinking.
4. Reuse open-source tools; we only write glue.
5. The harness must: remember where development stands, share repo-structure knowledge, and navigate code without grepping the whole repo.

## Architecture
**Distribution.** This repo is a private Claude Code plugin marketplace. Each consuming repo commits `.claude/settings.json` with `extraKnownMarketplaces` (pointing here) and `enabledPlugins` (core + its stacks). Project type = which plugins are enabled. New language = new plugin folder. Note: plugins from an external marketplace enabled only in project settings still need `claude plugin install --scope project` per developer, so `acme-init` must run it. Admins can restrict marketplaces via managed settings (`strictKnownMarketplaces`) and enable auto-update per marketplace.

**Plugins.**
| Plugin | Contents |
|---|---|
| acme-core | Guardrails (PreToolUse), session context (SessionStart), progress enforcement (Stop), PreCompact re-injection, repo map, skills: start-work, handoff (later: spec, implement, review) |
| acme-terraform | terraform-ls via `.lsp.json`, fmt+tflint on edit, validate/checkov on Stop, tf-plan-review skill, HashiCorp Terraform MCP server for registry docs |
| acme-python | depends on official `pyright-lsp`; ruff format/check on edit; type check + tests on Stop |
| acme-typescript | depends on official `typescript-lsp`; biome or eslint/prettier on edit; tsc + tests on Stop |
| acme-go | depends on official `gopls-lsp`; gofmt/goimports on edit; golangci-lint + go test on Stop |

**Tool installation.** Plugins do not install binaries. Every consuming repo has a `mise.toml` pinning its tools. Hooks call the same task runner as CI (`mise run lint`, lefthook/pre-commit) so the AI is held to exactly the CI standard.

**Code navigation (no whole-repo grep).**
1. LSP (built into Claude Code, enabled by LSP plugins): definitions, references, call hierarchy, diagnostics after each edit. Not available in cloud sessions.
2. ast-grep for structural search and codemods.
3. Repo map: generated at SessionStart, cached by git tree hash, gitignored (`.ai/cache/repo-map.md`): directory tree, top-level symbols (universal-ctags / tree-sitter), `go list ./...`, Terraform module/resource index (terraform-config-inspect or terraform-docs). Compact table of contents, not a dump.
4. Fallback to evaluate only if needed: Serena MCP.

**Shared repo knowledge.** Claude Code's auto memory is per-developer and local, so shared knowledge lives in the repo: short human-owned `CLAUDE.md` importing `docs/ai/ARCHITECTURE.md`; path-scoped `.claude/rules/*.md` (e.g. Terraform rules only for `**/*.tf`); the generated repo map.

**Development state.** `.ai/work/<branch>/` with `spec.md`, `plan.md` (checkboxes), `progress.md` (dated log). Committed on the branch, so it travels with the PR and any colleague/session can resume. SessionStart injects status; Stop asks Claude to update it when code changed; PreCompact re-injects the plan. Ticketing system stays the source of truth for *what*; this folder is working memory for *how far*. Before extending this, evaluate GitHub spec-kit and Beads to avoid reinventing.

**Guardrails.** No apply/destroy/import/state mutation (CI applies), no force-push, no reading `.env`, tfstate or key material. Enforced in hooks, because CLAUDE.md is context, not enforcement.

## Don't reinvent (tool shortlist)
mise, lefthook or pre-commit, ripgrep, ast-grep, universal-ctags, terraform-ls, tflint, checkov or trivy, terraform-docs, infracost (optional), HashiCorp terraform-mcp-server, ruff, pyright, biome/eslint, golangci-lint, bats, shellcheck, jq.

## Rollout
Pilot core + terraform + one language with 3–5 volunteers on one infra repo and one mixed repo; tag releases; pin consuming repos to tags; upstream people's best personal tricks as skills; add reviewer subagents once stable.
