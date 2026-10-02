# Plan

## Phase 0: validate the scaffold

- [x] Answer open question 1; rename "acme" → "jig" everywhere (marketplace, plugin names, docs) — verified by: `grep -ri acme` shows only the historical progress log (and the local checkout dir name)
- [x] `mise install`; pin exact tool versions in mise.toml — verified by: `mise ls` shows pinned versions
- [x] `mise run test` and `mise run lint` green, including `claude plugin validate` on both plugins (fix hooks.json/.lsp.json against current docs if needed) — verified by: command output
- [x] Add `tests/fixtures/tf-sample/` (small module with a variable, a local module call and an output) — verified by: `terraform validate` passes in it
- [x] Manual smoke test with `claude --plugin-dir` in the fixture: SessionStart context appears, `terraform apply` is blocked, editing a .tf triggers fmt/tflint feedback, LSP go-to-definition works on a module reference — verified by: notes in progress.md

## Phase 1: core + terraform to pilot quality

- [x] Re-inject plan status after compaction: session-start.sh prints the current plan phase when `source` is `compact` (PreCompact stdout does not reach Claude, per current docs) — verified by: `tests/session-start.bats`
- [x] Repo map: codebase-memory-mcp 0.11.0 in jig-core `.mcp.json` (locked-down wrapper, mise `ubi:` pin); HCL works on the tf fixture, so no terraform-docs index; SessionStart one-line status — verified by: smoke test (index + search_graph + module call via MCP in `claude -p`), `tests/repo-map.bats`. Snapshot bootstrap NOT met: restore from `graph.db.zst` not observed, so the pilot doesn't commit snapshots (fast index of a 5k-file repo ≈ 10 s wall)
- [ ] Security review of codebase-memory-mcp before rollout beyond the pilot (binary provenance/checksums, network behaviour, daemon) — verified by: written review
- [x] Short skill teaching navigation order: repo map (graph query) → LSP → ast-grep → grep (`jig-core:navigate-code`) — verified by: review (pending human), skill loads in smoke test
- [x] ADRs with Archgate: plugin needs `archgate login`, so CLI only (`github:archgate/cli` 0.58.0, telemetry off) + `jig-core:adrs` skill; `archgate check` in the jig-init lint template; templates GEN-001 and TF-001 (git module sources pin `?ref=`) — verified by: `tests/archgate.bats` (fails on violation, passes when pinned)
- [ ] OpenWiki pilot, **local**: `jig-openwiki` plugin (MCP `openwiki mcp --host claude` 0.5.2, Claude Code writes pages with the developer's session) + skill + `jig-init --openwiki` (enables plugin, pins node + openwiki) — DONE: `tests/openwiki.bats`, `tests/jig-init.bats`, smoke (MCP connected, 6 tools, skill listed); still to verify: one full init on a pilot repo (page quality, time, plan quota used)
- [x] jig-terraform Stop hook: offline `init -backend=false` + `validate` + `trivy config` (HIGH/CRITICAL) on modules edited this session, terraform or tofu, repo left untouched — verified by: `tests/terraform-hooks.bats`
- [x] Terraform conventions as path-scoped content: both. Company-wide in skill `jig-terraform:terraform-conventions` (`paths:`; plugins can't ship rules), repo-specific in `.claude/rules/terraform.md` from jig-init — verified by: review (pending human)
- [x] HashiCorp terraform-mcp-server 1.3.0 in jig-terraform `.mcp.json` (no release binaries: mise `go:` backend; `registry` toolset only) — verified by: `get_latest_provider_version` in smoke test
- [x] `bootstrap/jig-init`: detect stack, merge `.claude/settings.json`, `mise.toml`, `CLAUDE.md` + `docs/ai/ARCHITECTURE.md` skeletons, rules, `.archgate/adrs/`, optional `jig-openwiki` plugin, `mise install`, repo-map UI off, `claude plugin install … --scope project` (no snapshot, no `.ai/cache/`: unused) — verified by: `tests/jig-init.bats` (tf-only, py-only, mixed, idempotent). Real plugin install untested until the marketplace URL exists
- [x] bats tests for require-progress, tf-post-edit, detect-stack — verified by: `mise run test` (80 tests)

## Phase 2: language plugins

- [x] jig-python (depends on pyright-lsp; ruff on edit; pyright + pytest on Stop; python-conventions skill; jig-init pins uv/ruff/pyright) — verified by: `tests/fixtures/py-sample`, `tests/python-hooks.bats` (22), `tests/jig-init.bats`, smoke (`claude -p`: LSP definition, ruff reformat on edit, Stop blocked on pyright error, fixed)
- [x] jig-typescript (depends on typescript-lsp; biome or prettier+eslint on edit, detected per repo; tsc + vitest/`<pm> test` on Stop; typescript-conventions skill; jig-init pins per detected linter) — verified by: `tests/fixtures/ts-sample`, `tests/typescript-hooks.bats` (35), `tests/jig-init.bats`, smoke (`claude -p`: LSP definition, biome reformat on edit, LSP TS2322 diagnostic, Stop blocked on tsc error, fixed)
- [x] jig-go (depends on gopls-lsp; goimports on edit; golangci-lint + go test on Stop for edited packages; go-conventions skill; jig-init pins golangci-lint/gopls/goimports) — verified by: `tests/fixtures/go-sample`, `tests/go-hooks.bats` (25), smoke (`claude -p`: LSP definition, goimports reformat on edit, Stop blocked on failing go test, fixed)
- [x] Hooks call the consuming repo's task runner when present (`mise run lint`, run once by jig-core on Stop), falling back to direct tool calls (stack Stop hooks skip their static checks when the task exists) — verified by: `tests/lint-task.bats` (17), a skip test in each stack suite, a manual run against real mise

## Phase 2b: Terraform ADRs + automated enforcement

Layering: tflint (shipped config) for style, trivy for security, Archgate `.rules.ts` for repo/structure rules no linter has, bats to prove each rule fails on a bad example and passes on a good one. Opt-out: `archgate-ignore <ADR-ID>/<rule-id> <reason>` on the line before (reason required; replaced the custom `jig:allow`). Cloud-specific ADRs out of scope (trivy covers them).

- [x] Spike: Archgate rules API (glob, grep, readFile; no HCL parser; do relative imports from `.rules.ts` work?) — verified by: notes in progress.md
- [x] Shared HCL helper for rules, copied into each rule file because Archgate blocks imports (comment/string masking, block extraction) — verified by: bats
- [x] TF-002 no provider/backend blocks in child modules (`modules/` path segment) — verified by: `tests/archgate-terraform.bats` fail + pass fixtures
- [x] TF-006 root modules commit `.terraform.lock.hcl` — verified by: fail + pass fixtures
- [x] TF-007 `prevent_destroy` on stateful resources in prod roots — verified by: fail + pass + allow-comment fixtures
- [x] TF-009 no secrets in `.tfvars`/defaults, `sensitive = true` on secret variables — verified by: fail + pass fixtures
- [x] TF-003 tflint config template (structure, naming, documented/typed variables and outputs) + ADR — verified by: tflint flags a bad fixture and passes tf-sample
- [x] `jig-init` copies the TF ADRs, helper and `.tflint.hcl` for Terraform repos only — verified by: `tests/jig-init.bats`
- [x] Skills reference ADR IDs; drift test (every template ADR is referenced by a skill and vice versa); jig-terraform version bump; DESIGN.md updated — verified by: `mise run test`, `mise run lint`
- [ ] Dogfood on a pilot Terraform repo, note false-positive rate — verified by: progress.md

## Phase 3: distribution and pilot

- [ ] CI for this repo: test, lint, validate on every MR — verified by: green pipeline
- [ ] Tag v0.1.0; document upgrade process — verified by: tag exists, README section
- [ ] Draft managed-settings snippet for admins (marketplace allowlist, auto-update) — verified by: review with admin
- [ ] Enable on pilot repos with jig-init; collect feedback in progress.md — verified by: 2 repos onboarded
