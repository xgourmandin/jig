# Jig Claude Code harness — design

## Goals
1. One shared, versioned harness instead of personal, non-shareable setups.
2. Adapts per project: code only, infra only, or both. Languages: Python, TypeScript, Go now; more later.
3. Deterministic tools do the checking; the model does the thinking.
4. Reuse open-source tools; we only write glue.
5. The harness must: remember where development stands, share repo-structure knowledge, and navigate code without grepping the whole repo.

## Architecture
**Distribution.** This repo is a private Claude Code plugin marketplace. Each consuming repo commits `.claude/settings.json` with `extraKnownMarketplaces` (pointing here) and `enabledPlugins` (core + its stacks). Project type = which plugins are enabled. New language = new plugin folder. Note: plugins from an external marketplace enabled only in project settings still need `claude plugin install --scope project` per developer, so `jig-init` must run it. Admins can restrict marketplaces via managed settings (`strictKnownMarketplaces`) and enable auto-update per marketplace. Language plugins depend on the official LSP plugins (`claude-plugins-official`, allowed by `allowCrossMarketplaceDependenciesOn` in our marketplace.json), so we don't ship our own LSP configs for them.

**Plugins.**
| Plugin | Contents |
|---|---|
| jig-core | Guardrails (PreToolUse), session context (SessionStart), progress enforcement (Stop), plan re-injection after compaction (SessionStart `compact`), repo map (codebase-memory-mcp MCP server + SessionStart status), skills: start-work, handoff, navigate-code, adrs (later: spec, implement, review) |
| jig-terraform | Terraform or OpenTofu (picked per repo). terraform-ls via `.lsp.json`, fmt+tflint on edit, offline validate + trivy on Stop for modules edited in the session, skills: terraform-conventions (path-scoped), tf-plan-review; HashiCorp terraform-mcp-server (registry toolset only) for provider/module docs |
| jig-python | depends on official `pyright-lsp` (auto-installed; the plugin is disabled if the dependency is missing); ruff format + safe fixes on edit; pyright on edited files + pytest on Stop for projects edited in the session; tools from the project `.venv` first, pytest via `uv run` when `uv.lock` exists; skill: python-conventions (path-scoped) |
| jig-typescript | depends on official `typescript-lsp` (auto-installed; needs the project's TypeScript ≤ 6 in node_modules for tsserver); per repo: `biome check --write`, or prettier (only if the repo uses it) + `eslint --fix`, on edit; `tsc --noEmit` + vitest (fallback `<pm> test`) on Stop for packages edited in the session; tools from `node_modules/.bin` first; skill: typescript-conventions (path-scoped) |
| jig-go | depends on official `gopls-lsp` (auto-installed; the plugin is disabled if the dependency is missing); goimports (fallback gofmt) on edit, no linter on edit (gopls diagnostics cover compile/vet); golangci-lint v2 (repo `.golangci.yml`; `go vet` if missing) + `go test` on Stop for the packages edited in the session, per module (nearest go.mod), `-mod=readonly` so go.mod/go.sum never change; skill: go-conventions (path-scoped) |
| jig-openwiki | Opt-in generated wiki: OpenWiki MCP server (host-driven, no API key) + skill; run locally, reviewed in a PR |

**Tool installation.** Plugins do not install binaries. Every consuming repo has a `mise.toml` pinning its tools. Hooks call the same task runner as CI (`mise run lint`) so the AI is held to exactly the CI standard: when the repo defines a mise `lint` task, jig-core runs it once on Stop (if Claude edited files) and the stack plugins skip their own static checks (type checkers, linters, trivy), keeping per-edit formatting and their tests. Without a lint task they call the tools directly. No git-hook tool yet; lefthook is the default when we add one. No cloud credentials in sessions: Terraform checks are offline (`init -backend=false`), plans come from CI.

**Code navigation (no whole-repo grep).**
1. LSP (built into Claude Code, enabled by LSP plugins): definitions, references, call hierarchy, diagnostics after each edit. Not available in cloud sessions.
2. ast-grep for structural search and codemods.
3. Repo map: a queryable code knowledge graph from [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) (MIT, single binary, MCP server: functions, call chains, routes, cross-service links). HCL is supported (verified on the fixture: modules, outputs, module calls with line numbers), so no separate terraform-docs index. Its watcher reindexes incrementally. A fast index takes seconds (5k-file repo: ~5 s of work plus a ~5 s CLI startup floor), so the pilot does **not** commit the `.codebase-memory/graph.db.zst` snapshot: restoring from it was not observed in v0.11.0. SessionStart injects one status line, not a dump. **Pilot, locked down:** pinned release binary via mise, started only through `scripts/repo-map-mcp.sh` (stdio, `CBM_ALLOWED_ROOT` = project), never its installer (which auto-configures every agent); jig-init turns off its local HTTP UI (default on, 127.0.0.1:9749). Its short-lived background daemon exits when idle. Security review required before rollout (unusual star growth, binary flagged by Defender per its own README). Alternatives if the pilot rejects it: CodeGraph, Graphify (both MIT).
4. Fallback to evaluate only if needed: Serena MCP.

**Shared repo knowledge.** Claude Code's auto memory is per-developer and local, so shared knowledge lives in the repo, in four layers:
1. *Conventions (human-written):* short `CLAUDE.md` importing `docs/ai/ARCHITECTURE.md`; path-scoped `.claude/rules/*.md` for repo-specific rules (e.g. Terraform rules only for `**/*.tf`). Plugins cannot ship rules, so company-wide conventions are path-scoped skills (`paths:` frontmatter) in the stack plugins.
2. *Decisions (why, enforced):* ADRs with [Archgate](https://github.com/archgate/cli) (Apache-2.0) in `.archgate/adrs/`, each with an optional `.rules.ts` check. `archgate check` runs in `mise run lint`, so CI, pre-commit and the agent use the same checks; the jig-core `adrs` skill makes the agent read the relevant ADRs (`archgate review-context`) before coding and propose new ones. We use the CLI only: Archgate's Claude Code plugin requires `archgate login` to its hosted platform. Its telemetry is on by default, so repos set `ARCHGATE_TELEMETRY=0` in `mise.toml`. Company-wide ADRs could later live here and be pulled with `archgate adr import`/`sync`.
3. *How it works (generated, reviewed):* [OpenWiki](https://github.com/langchain-ai/openwiki) (MIT) writes a Markdown wiki to `openwiki/` and points CLAUDE.md at it. It runs **locally, not in CI**: a CI job needs a metered provider API key, which costs too much. OpenWiki's host-driven mode lets Claude Code do the research and writing with the developer's own Claude session, while OpenWiki keeps the page queue, Grounded Claims (facts tied to source lines, flagged when those lines change) and finalization. A developer asks Claude to update the wiki on a branch, and humans review the diff in a normal PR. Opt-in per repo: `jig-init --openwiki` enables the `jig-openwiki` plugin (MCP server `openwiki mcp --host claude` + skill) and pins `node` + `npm:openwiki` (telemetry off). We skip `openwiki integrations install`, which writes user-level config. Trade-off: updates happen when someone runs them, not on a schedule. It maintains its own block in CLAUDE.md/AGENTS.md.
4. *Where things are (generated):* the repo map above.
Cross-tool rule sync (rulesync) is out of scope while the harness targets Claude Code only; revisit if developers ask for Cursor or Copilot support.

**Development state.** `.ai/work/<branch>/` with `spec.md`, `plan.md` (checkboxes), `progress.md` (dated log). Committed on the branch, so it travels with the PR and any colleague/session can resume. SessionStart injects status; Stop asks Claude to update it when code changed; after compaction, SessionStart (source `compact`) re-injects the current plan phase (PreCompact output never reaches Claude). Ticketing system stays the source of truth for *what*; this folder is working memory for *how far*. Before extending this, evaluate GitHub spec-kit and Beads to avoid reinventing.

**Guardrails.** No apply/destroy/import/state mutation (CI applies), no force-push, no reading `.env`, tfstate or key material. Enforced in hooks, because CLAUDE.md is context, not enforcement.

## Don't reinvent (tool shortlist)
mise, lefthook (later), ripgrep, ast-grep, codebase-memory-mcp, Archgate, OpenWiki, terraform-ls, tflint, trivy, OpenTofu, infracost (optional), HashiCorp terraform-mcp-server, ruff, pyright, biome/eslint, golangci-lint, bats, shellcheck, jq.

## Rollout
Pilot core + terraform + one language with 3–5 volunteers on one infra repo and one mixed repo; tag releases; pin consuming repos to tags; upstream people's best personal tricks as skills; add reviewer subagents once stable.
