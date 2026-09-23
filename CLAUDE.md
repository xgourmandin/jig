# Jig Claude harness — instructions for Claude Code

This repo is Jig's **Claude Code plugin marketplace**: the shared "company harness" every Jig repo uses for AI-assisted coding (software and Terraform). Read @docs/DESIGN.md for the why. The marketplace Git URL is not decided yet (placeholder in README.md).

## Layout
- `.claude-plugin/marketplace.json`: marketplace catalog (one entry per plugin)
- `plugins/jig-core/`: always-on core (guardrails, per-branch work state, repo map MCP, workflow skills)
- `plugins/jig-terraform/`: Terraform/OpenTofu stack (terraform-ls LSP, fmt/tflint/validate/trivy hooks, registry MCP, skills)
- `plugins/jig-openwiki/`: opt-in generated wiki (OpenWiki MCP driven by Claude Code, run locally)
- `plugins/jig-python/`: Python stack (depends on official `pyright-lsp`; ruff on edit, pyright + pytest on Stop, skill)
- `plugins/jig-go/`: Go stack (depends on official `gopls-lsp`; goimports on edit, golangci-lint + go test on Stop, skill)
- `plugins/jig-typescript/`: TypeScript/JS stack (depends on official `typescript-lsp`; biome or prettier+eslint on edit, tsc + vitest/npm test on Stop, skill)
- `bootstrap/`: `jig-init` sets up a consuming repo (uses `detect-stack.sh` and `templates/`)
- `tests/`: bats tests for every hook script
- `.ai/work/<branch>/`: work state (spec, plan, progress) — we dogfood the harness here

## Commands
- `mise install`: install pinned tools (jq, bats, shellcheck, terraform, opentofu, terraform-ls, tflint, trivy, archgate, codebase-memory-mcp, terraform-mcp-server, node, openwiki)
- `mise run test`: bats tests
- `mise run lint`: shellcheck + `claude plugin validate`
- Try a plugin locally without installing: `claude --plugin-dir ./plugins/jig-core --plugin-dir ./plugins/jig-terraform`. A plugin whose `dependencies` are not installed is disabled (`dependency-unsatisfied`), so first run `claude plugin install <pyright-lsp|typescript-lsp|gopls-lsp>@claude-plugins-official --scope project` in the sample repo (for jig-python / jig-typescript / jig-go)
- Set up a sample repo: `bootstrap/jig-init --marketplace-url . --no-install <repo>`
- The rtk hook breaks `mise run …` output; use `rtk proxy mise run test`

## Rules for this repo
- Hooks are **deterministic bash + jq**, not prompt hooks. They read the hook JSON on stdin; block with exit 2 + stderr (PreToolUse/PostToolUse) or `{"decision":"block","reason":...}` (Stop). Stop hooks never block twice in a row: when `stop_hook_active` is true they re-check and only report (`systemMessage`).
- Guardrails **fail closed** when a dependency is missing; convenience hooks fail open with a message.
- Every hook script gets bats tests in `tests/` covering both allow and block cases. Keep shellcheck clean.
- Reference plugin files with `${CLAUDE_PLUGIN_ROOT}`, never absolute paths.
- Prefer existing open-source tools over writing our own (see "Don't reinvent" in DESIGN.md). Write glue, not tools.
- Plugin/hook/LSP schemas change often: before adding or changing a component, check the current docs at https://code.claude.com/docs/en/plugins-reference and https://code.claude.com/docs/en/hooks rather than relying on memory.
- Bump the plugin `version` in both `plugin.json` and `marketplace.json` when a plugin changes.
- Never run `terraform apply`/`destroy` (the guard will block it anyway).
