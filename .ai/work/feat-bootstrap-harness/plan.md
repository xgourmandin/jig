# Plan

## Phase 0: validate the scaffold
- [ ] Answer open question 1; rename "acme" everywhere (marketplace, plugin names, docs) — verified by: `grep -ri acme` shows only intended hits
- [ ] `mise install`; pin exact tool versions in mise.toml — verified by: `mise ls` shows pinned versions
- [ ] `mise run test` and `mise run lint` green, including `claude plugin validate` on both plugins (fix hooks.json/.lsp.json against current docs if needed) — verified by: command output
- [ ] Add `tests/fixtures/tf-sample/` (small module with a variable, a local module call and an output) — verified by: `terraform validate` passes in it
- [ ] Manual smoke test with `claude --plugin-dir` in the fixture: SessionStart context appears, `terraform apply` is blocked, editing a .tf triggers fmt/tflint feedback, LSP go-to-definition works on a module reference — verified by: notes in progress.md

## Phase 1: core + terraform to pilot quality
- [ ] PreCompact hook that re-injects plan status (reuse session-start logic) — verified by: bats test
- [ ] Repo map generator `acme-core/bin/repo-map` (tree + universal-ctags + go list + terraform module index), cached by `git write-tree` hash in `.ai/cache/`, injected (truncated) at SessionStart — verified by: bats test + timing on a medium repo
- [ ] Short skill teaching navigation order: repo map → LSP → ast-grep → grep — verified by: review
- [ ] acme-terraform Stop hook: `terraform validate` (+ checkov or trivy config) on modules changed in this session — verified by: bats test with fixture
- [ ] Terraform conventions as path-scoped content (decide: skill vs rules template copied by acme-init) — verified by: review
- [ ] Add HashiCorp terraform-mcp-server to acme-terraform `.mcp.json` (check current install method) — verified by: tool call in smoke test
- [ ] `bootstrap/acme-init`: detect stack, write `.claude/settings.json`, `mise.toml`, `CLAUDE.md` + `docs/ai/ARCHITECTURE.md` skeletons, add `.ai/cache/` to .gitignore, run `claude plugin install … --scope project` — verified by: bats test on temp repos (tf-only, py-only, mixed)
- [ ] bats tests for session-start, require-progress, tf-post-edit, detect-stack — verified by: `mise run test`

## Phase 2: language plugins
- [ ] acme-python (depends on pyright-lsp; ruff on edit; type check + pytest on Stop) — verified by: fixture + bats
- [ ] acme-typescript (depends on typescript-lsp; linter/formatter on edit; tsc + tests on Stop) — verified by: fixture + bats
- [ ] acme-go (depends on gopls-lsp; gofmt/goimports on edit; golangci-lint + go test on Stop) — verified by: fixture + bats
- [ ] Hooks call the consuming repo's task runner when present (`mise run lint`), falling back to direct tool calls — verified by: bats

## Phase 3: distribution and pilot
- [ ] CI for this repo: test, lint, validate on every MR — verified by: green pipeline
- [ ] Tag v0.1.0; document upgrade process — verified by: tag exists, README section
- [ ] Draft managed-settings snippet for admins (marketplace allowlist, auto-update) — verified by: review with admin
- [ ] Enable on pilot repos with acme-init; collect feedback in progress.md — verified by: 2 repos onboarded
