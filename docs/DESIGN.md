# Jig Claude Code harness — design

## Goals
1. One shared, versioned harness instead of personal, non-shareable setups.
2. Adapts per project: code only, infra only, or both. Languages: Python, TypeScript, Go now; more later.
3. Deterministic tools do the checking; the model does the thinking.
4. Reuse open-source tools; we only write glue.
5. The harness must: remember where development stands, share repo-structure knowledge, and navigate code without grepping the whole repo.

## Architecture
**Distribution.** This repo is a private Claude Code plugin marketplace. Each consuming repo commits `.claude/settings.json` with `extraKnownMarketplaces` (pointing here) and `enabledPlugins` (core + its stacks). Project type = which plugins are enabled. New language = new plugin folder. Note: plugins from an external marketplace enabled only in project settings still need `claude plugin install --scope project` per developer, so `jig-init` must run it. Admins can restrict marketplaces via managed settings (`strictKnownMarketplaces`) and enable auto-update per marketplace.

**Plugins.**
| Plugin | Contents |
|---|---|
| jig-core | Guardrails (PreToolUse), session context (SessionStart), progress enforcement (Stop), PreCompact re-injection, repo map (codebase-memory-mcp), Archgate ADR checks, skills: start-work, handoff (later: spec, implement, review) |
| jig-terraform | terraform-ls via `.lsp.json`, fmt+tflint on edit, validate/checkov on Stop, tf-plan-review skill, HashiCorp Terraform MCP server for registry docs |
| jig-python | depends on official `pyright-lsp`; ruff format/check on edit; type check + tests on Stop |
| jig-typescript | depends on official `typescript-lsp`; biome or eslint/prettier on edit; tsc + tests on Stop |
| jig-go | depends on official `gopls-lsp`; gofmt/goimports on edit; golangci-lint + go test on Stop |

**Tool installation.** Plugins do not install binaries. Every consuming repo has a `mise.toml` pinning its tools. Hooks call the same task runner as CI (`mise run lint`, lefthook/pre-commit) so the AI is held to exactly the CI standard.

**Code navigation (no whole-repo grep).**
1. LSP (built into Claude Code, enabled by LSP plugins): definitions, references, call hierarchy, diagnostics after each edit. Not available in cloud sessions.
2. ast-grep for structural search and codemods.
3. Repo map: a queryable code knowledge graph from [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) (MIT, single binary, MCP server: functions, call chains, routes, cross-service links). Its background watcher reindexes incrementally; each repo commits the compressed snapshot (`.codebase-memory/graph.db.zst`) so teammates skip the full reindex. HCL coverage is unconfirmed, so Terraform keeps a terraform-docs module/resource index. SessionStart injects only a short summary, not a dump. Alternatives if the pilot rejects it: CodeGraph, Graphify (both MIT).
4. Fallback to evaluate only if needed: Serena MCP.

**Shared repo knowledge.** Claude Code's auto memory is per-developer and local, so shared knowledge lives in the repo, in four layers:
1. *Conventions (human-written):* short `CLAUDE.md` importing `docs/ai/ARCHITECTURE.md`; path-scoped `.claude/rules/*.md` (e.g. Terraform rules only for `**/*.tf`).
2. *Decisions (why, enforced):* ADRs with [Archgate](https://github.com/archgate/cli) (Apache-2.0) in `.archgate/adrs/`, each with an optional `.rules.ts` check. `archgate check` runs in `mise run lint`, so CI, pre-commit and the agent use the same checks; its Claude Code plugin makes the agent read the relevant ADRs before coding and propose new ones.
3. *How it works (generated, reviewed):* [OpenWiki](https://github.com/langchain-ai/openwiki) (MIT) writes a Markdown wiki to `openwiki/` and points CLAUDE.md at it. It runs in CI, not in sessions: a scheduled job refreshes pages from git diffs and opens a PR, so humans review what becomes shared knowledge. Opt-in per repo (LLM cost).
4. *Where things are (generated):* the repo map above.
Cross-tool rule sync (rulesync) is out of scope while the harness targets Claude Code only; revisit if developers ask for Cursor or Copilot support.

**Development state.** `.ai/work/<branch>/` with `spec.md`, `plan.md` (checkboxes), `progress.md` (dated log). Committed on the branch, so it travels with the PR and any colleague/session can resume. SessionStart injects status; Stop asks Claude to update it when code changed; PreCompact re-injects the plan. Ticketing system stays the source of truth for *what*; this folder is working memory for *how far*. Before extending this, evaluate GitHub spec-kit and Beads to avoid reinventing.

**Guardrails.** No apply/destroy/import/state mutation (CI applies), no force-push, no reading `.env`, tfstate or key material. Enforced in hooks, because CLAUDE.md is context, not enforcement.

## Don't reinvent (tool shortlist)
mise, lefthook or pre-commit, ripgrep, ast-grep, codebase-memory-mcp, Archgate, OpenWiki, terraform-ls, tflint, checkov or trivy, terraform-docs, infracost (optional), HashiCorp terraform-mcp-server, ruff, pyright, biome/eslint, golangci-lint, bats, shellcheck, jq.

## Rollout
Pilot core + terraform + one language with 3–5 volunteers on one infra repo and one mixed repo; tag releases; pin consuming repos to tags; upstream people's best personal tricks as skills; add reviewer subagents once stable.
