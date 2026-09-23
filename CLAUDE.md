# Jig Claude harness — instructions for Claude Code

This repo is Jig's **Claude Code plugin marketplace**: the shared "company harness" every Jig repo uses for AI-assisted coding (software and Terraform). Read @docs/DESIGN.md for the why. The marketplace Git URL is not decided yet (placeholder in README.md).

## Layout
- `.claude-plugin/marketplace.json`: marketplace catalog (one entry per plugin)
- `plugins/jig-core/`: always-on core (guardrails, per-branch work state, workflow skills)
- `plugins/jig-terraform/`: Terraform stack (terraform-ls LSP, fmt/tflint hooks, plan review)
- `plugins/jig-{python,typescript,go}/`: to be created (see plan)
- `bootstrap/`: scripts that set up a consuming repo (`detect-stack.sh`, later `jig-init`)
- `tests/`: bats tests for every hook script
- `.ai/work/<branch>/`: work state (spec, plan, progress) — we dogfood the harness here

## Commands
- `mise install`: install pinned tools (jq, bats, shellcheck, terraform, terraform-ls, tflint)
- `mise run test`: bats tests
- `mise run lint`: shellcheck + `claude plugin validate`
- Try a plugin locally without installing: `claude --plugin-dir ./plugins/jig-core --plugin-dir ./plugins/jig-terraform`

## Rules for this repo
- Hooks are **deterministic bash + jq**, not prompt hooks. They read the hook JSON on stdin; block with exit 2 + stderr (PreToolUse/PostToolUse) or `{"decision":"block","reason":...}` (Stop).
- Guardrails **fail closed** when a dependency is missing; convenience hooks fail open with a message.
- Every hook script gets bats tests in `tests/` covering both allow and block cases. Keep shellcheck clean.
- Reference plugin files with `${CLAUDE_PLUGIN_ROOT}`, never absolute paths.
- Prefer existing open-source tools over writing our own (see "Don't reinvent" in DESIGN.md). Write glue, not tools.
- Plugin/hook/LSP schemas change often: before adding or changing a component, check the current docs at https://code.claude.com/docs/en/plugins-reference and https://code.claude.com/docs/en/hooks rather than relying on memory.
- Bump the plugin `version` in both `plugin.json` and `marketplace.json` when a plugin changes.
- Never run `terraform apply`/`destroy` (the guard will block it anyway).
