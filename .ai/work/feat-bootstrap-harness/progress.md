# Progress

## 2026-09-23 — claude (claude.ai, design session)
Done: design agreed (docs/DESIGN.md). Scaffolded marketplace with acme-core (guard, session-start, require-progress hooks; start-work and handoff skills) and acme-terraform (terraform-ls .lsp.json, fmt/tflint PostToolUse hook, tool check, tf-plan-review skill), bootstrap/detect-stack.sh, bats tests for guard.sh (13/13 passing), shellcheck clean.
Decisions: bash+jq hooks for determinism; guardrail fails closed if jq missing; work state keyed by branch name; hooks.json uses the `{"hooks": {...}}` wrapper.
Not yet verified: `claude plugin validate`, terraform-ls LSP wiring and hooks inside a real Claude Code session (no Claude Code or terraform binaries in the design environment).
Next: Phase 0, task 1 — ask the human for the company name and Git host URL.
Blockers: open questions in spec.md.

## 2026-09-23 — claude (Claude Code, design revision)
Done: researched OSS tools for shared repo knowledge; DESIGN.md now has four layers: conventions (CLAUDE.md + rules), decisions (Archgate ADRs, enforced in lint), generated wiki (OpenWiki via CI PRs, opt-in), repo map (codebase-memory-mcp replaces the planned ctags generator). Plan/spec updated.
Decisions: rulesync skipped (Claude Code only). Keep terraform-docs for Terraform because the graph tools' HCL support is unconfirmed.
Not yet verified: none of the new tools tested; Archgate plugin may require `archgate login`; OpenWiki maturity/cost unknown.
Next: Phase 0 unchanged.

## 2026-09-23 — claude (Claude Code, Phase 0)
Done: Phase 0 complete.
- Renamed acme → jig (open question 1): plugin dirs `plugins/jig-{core,terraform}`, marketplace `jig`, docs, `jig_work_dir`. Earlier progress entries keep "acme" as history. Plugins stay at 0.1.0 (never released, so no bump).
- mise.toml pins jq 1.8.2, shellcheck 0.11.0, bats 1.14.0, terraform 1.16.3, terraform-ls 0.39.0, tflint 0.64.0 (all were the latest versions).
- `mise run test`: 13/13. `mise run lint`: shellcheck clean; `claude plugin validate` passes for both plugins and the marketplace (added `validate .` to lint). Checked hooks.json/.lsp.json against current docs (Claude Code 2.1.280): wrapper and top-level `description` allowed, timeouts are in seconds, and Stop `{decision:"block",reason}` is still valid. No changes needed.
- Fixture `tests/fixtures/tf-sample/` (variable, local module `./modules/naming`, output): `terraform validate` OK, `tflint --recursive` clean, fmt clean.
- Smoke test (headless `claude -p --plugin-dir` for both plugins, sonnet):
  - SessionStart context injected (branch, plan counts, next task, last progress entry).
  - `terraform apply -help` was blocked by guard.sh.
  - An Edit adding an untyped unused variable made terraform fmt fix the spacing, and tflint fed back typed_variables and unused_declarations via exit 2.
  - LSP go-to-definition on `module.naming.full_name` resolved to the module block and `modules/naming/main.tf:15` (output).
  - Stop hook blocked once and Claude appended to progress.md.
Decisions: the marketplace Git URL is not decided yet; README uses the placeholder `https://git.example.com/TODO/jig-claude-harness.git`.
Findings for Phase 1:
- Hooks and the LSP need tools on Claude's PATH. mise shims/activation must be active when `claude` starts (in non-interactive shells mise isn't activated; check-tools.sh already warns). Document this in jig-init.
- The Stop hook could use `hookSpecificOutput.additionalContext` (shown as "Stop hook feedback", not a hook error) instead of `decision: block`.
- session-start.sh tells Claude to read spec.md even when it doesn't exist.
- The PostToolUse matcher lists `MultiEdit`, which may no longer be a tool; harmless.
Next: Phase 1. First ask open questions 2–4 (Terraform vs OpenTofu, clouds and credentials; lefthook/pre-commit; ticket system).
Blockers: none.

## 2026-09-23 — claude (Claude Code, Phase 1 start)
Done:
- Open questions 2–4 answered and recorded in spec.md: Terraform **and** OpenTofu; offline checks only (`init -backend=false`, validate, scanners; plan in CI); no pre-commit tooling yet (lefthook default later); no ticket linking.
- Task 1 (plan re-injection after compaction). Current hooks docs: PreCompact can only block compaction, and its stdout goes to the debug log, not to Claude. So there is no PreCompact hook. Instead, session-start.sh reads `source` from stdin, and on `compact` it also prints the plan.md section holding the first open task. SessionStart has no matcher, so it already fires after compaction. Also fixed: it only asks to read spec.md/plan.md when they exist. New `tests/session-start.bats` (8 tests); `mise run test` 21/21, `mise run lint` green. DESIGN.md updated.
Decisions: jig-core stays at 0.1.0 (unreleased, same as Phase 0).
Note: the rtk hook rewrite of `mise run test`/`mise run lint` prints "bash: command not found:"; run them with `rtk proxy mise run …`.
Next: repo map (codebase-memory-mcp in jig-core `.mcp.json`). Guard/fmt/validate hooks must handle `tofu` as well as `terraform` (the guard already does).
Blockers: none.

## 2026-09-23 — claude (Claude Code, Phase 1 build)
Done:
- Decisions from the human: codebase-memory-mcp as a locked-down pilot; terraform-mcp-server via `go install` through mise; CI templates for both GitHub and GitLab.
- jig-terraform: `lib.sh` picks `terraform` or `tofu` per repo. New Stop hook `tf-stop-validate.sh`: PostToolUse records edited module dirs in `${CLAUDE_PLUGIN_DATA}`. Stop runs offline `init -backend=false` + `validate`, then `trivy config` (HIGH/CRITICAL, embedded checks, no download), and blocks once. `.terraform` goes to the data dir and the lock file is restored. Also added: path-scoped `terraform-conventions` skill, tf-plan-review now prefers the CI plan, and terraform-mcp-server (`registry` toolset) via `scripts/terraform-mcp.sh`.
- jig-core: repo-map MCP (`scripts/repo-map-mcp.sh`, `CBM_ALLOWED_ROOT` = project), `repo-map-status.sh` (SessionStart, one CLI call), skills `navigate-code` and `adrs`.
- bootstrap: `jig-init` + templates (CLAUDE.md, ARCHITECTURE.md, terraform rules, GEN-001/TF-001 ADRs, OpenWiki GitHub/GitLab jobs). `detect-stack.sh` detects `.tofu` files.
- Harness mise.toml now pins opentofu, trivy, go, terraform-mcp-server, archgate, codebase-memory-mcp; `[env] ARCHGATE_TELEMETRY=0`.
- Tests: 80/80 (`tests/{session-start,terraform-hooks,repo-map,archgate,jig-init,require-progress,detect-stack}.bats`); lint green.
- Smoke (`claude -p` with both plugin dirs in a copy of the tf fixture): session context + repo-map hint injected; both MCP servers connected; indexed the fixture and `search_graph` found `full_name` in both files with lines and the `naming` module call; registry returned hashicorp/random 3.9.1; all four new skills listed.
Findings:
- PreCompact output never reaches Claude (current docs). Plan re-injection is SessionStart `compact`.
- codebase-memory-mcp: HCL works. Snapshot restore from a committed `graph.db.zst` not observed (clone reindexed fully, with path-derived or fixed `--name`), so no committed snapshot in the pilot. Every CLI call has a ~5 s floor (daemon handshake). Its daemon serves an HTTP UI on 127.0.0.1:9749 by default (jig-init disables it per user) and exits when idle. No phone-home URLs found in the binary. Test indexes deleted from `~/.cache/codebase-memory-mcp`.
- Archgate: the npm package is a shim that downloads an unversioned binary to `~/.archgate/bin` (hung here), so we pin the GitHub release instead. Telemetry defaults to on: this machine's `~/.archgate/config.json` was created with telemetry true by that first run. Set to false afterwards and removed the partial binary. `archgate init --editor claude` writes `.claude/settings.local.json` for its plugin agent, so jig-init writes `.archgate/` itself.
- OpenWiki sends CI telemetry by default (templates set `OPENWIKI_TELEMETRY_DISABLED=1`) and maintains its own block in CLAUDE.md/AGENTS.md.
- The harness pins both terraform and opentofu, so hooks pick `tofu` inside this repo (mise.toml mentions opentofu). Tests copy fixtures to temp repos, so unaffected.
Decisions: plugins stay 0.1.0 (unreleased). No `.ai/cache/` (Stop state lives in the plugin data dir).
Next: human review of the skills (navigate-code, adrs, terraform-conventions); security review of codebase-memory-mcp; OpenWiki verification on a pilot repo (needs repo + ANTHROPIC_API_KEY); then Phase 2.
(Superseded 2026-09-23: OpenWiki now runs locally, see below.)
Blockers: marketplace Git URL still undecided (real `claude plugin install` from jig-init untested).

## 2026-09-23 — OpenWiki: CI → local
Decision: drop the CI job (an Anthropic API key costs too much). OpenWiki runs locally in host-driven mode: Claude Code does the research and writing with the developer's session, and OpenWiki keeps the queue, Claims and finalization. No provider key.
Done:
- New opt-in plugin `jig-openwiki` 0.1.0: `.mcp.json` → `scripts/openwiki-mcp.sh` (`openwiki mcp --host claude`, `OPENWIKI_TELEMETRY_DISABLED=1`, clear error if not on PATH); skill `openwiki` = Jig preamble (branch, confirm before init, PR review) + upstream skill from openwiki@0.5.2 (MIT, LICENSE copied). Not `openwiki integrations install` (writes `~/.claude.json` and user skills).
- `jig-init --openwiki` is now a flag: enables `jig-openwiki@jig` and pins `node` + `npm:openwiki` + telemetry off in the new mise.toml (or prints a todo if mise.toml exists). The opt-in is sticky: later runs keep it when settings enable the plugin or `openwiki/` exists. `bootstrap/templates/ci/` removed.
- Harness mise.toml pins node 24.21.0 + npm:openwiki 0.5.2; lint validates the new plugin. Tests 83/83, lint green.
- Smoke (`claude -p --plugin-dir plugins/jig-openwiki` in the tf fixture copy, with mise tools on PATH): MCP connected in ~1.4 s, all 6 `openwiki_*` tools present, skill `jig-openwiki:openwiki` listed, `~/.openwiki` not created.
Findings:
- Claude Code truncates the server's MCP instructions (2378 → 2048 chars), so the full skill is needed.
- The first 3 smoke runs reported the server `failed` (the first because PATH lacked mise tools; the next two unexplained, no MCP lines in the log). Every later run connected. Watch for this in the pilot.
Next: one full `init` on a pilot repo to judge page quality, time and plan quota used.

## 2026-09-23 — claude (Claude Code, Phase 2 start: jig-python)
Decisions (open question 5, from the human): Python uses **pyright** and **uv**. TypeScript **detects per repo** (biome.json → biome, else eslint + prettier). Tests on Stop: **pytest / vitest (fallback `npm test`) / go test**, only when the session changed code in that language. Recorded in spec.md.
Done:
- Checked current docs: plugin `dependencies` in plugin.json support `{name, marketplace}`. The root marketplace must list `allowCrossMarketplaceDependenciesOn: ["claude-plugins-official"]` (added). The official LSP plugins are `pyright-lsp` (`pyright-langserver`), `typescript-lsp` (`typescript-language-server`) and `gopls-lsp` (`gopls`). `MultiEdit` is gone, so the new hooks match `Edit|Write`.
- New plugin `jig-python` 0.1.0:
  - PostToolUse `py-post-edit.sh`: `ruff format` + `ruff check --fix`, with repo config and `--force-exclude`. Remaining issues → exit 2. The file is recorded for Stop.
  - Stop `py-stop-check.sh`: per project (nearest pyproject.toml/setup.cfg/setup.py), runs `pyright --outputjson` on the edited files (errors only, with the project `.venv` python), then pytest (`uv run --frozen pytest` with uv.lock, else `.venv/bin/pytest`, else PATH). Blocks once. Missing tools only warn.
  - SessionStart `check-tools.sh`.
  - Path-scoped `python-conventions` skill.
- Repo stays clean: `RUFF_CACHE_DIR` in the plugin data dir, `pytest -p no:cacheprovider`, `PYTHONDONTWRITEBYTECODE=1`.
- Fixture `tests/fixtures/py-sample` (src layout, no third-party deps: pyright can't see a pipx pytest).
- jig-init: a Python stack enables jig-python and pins uv, ruff, npm:pyright and node, and adds `ruff format --check .`, `ruff check .` and `pyright` to lint.
- Harness mise.toml pins uv 0.12.17, ruff 0.16.8, npm:pyright 1.1.414 and pipx:pytest 9.1.1.
- Tests 106/106, lint green.
- Smoke (`claude -p --plugin-dir plugins/jig-python`, `pyright-lsp` installed at project scope in a throwaway copy of the fixture): LSP goToDefinition on `mean` → `calc.py:8:5`; the badly formatted `twice` was reformatted by ruff; LSP diagnostics flagged the return type right after the edit; the Stop hook blocked once with the pyright error; Claude fixed the body; the next stop passed. Uninstalled afterwards.
Findings:
- **A plugin with a missing dependency is disabled entirely** (`plugin_errors: dependency-unsatisfied`), hooks included. The first smoke run silently had no jig-python. Marketplace installs auto-install dependencies (per docs, untested until the marketplace URL exists). With `--plugin-dir`, install `pyright-lsp` first (noted in CLAUDE.md).
- ruff creates `.ruff_cache/` even with `--no-cache`, so we redirect `RUFF_CACHE_DIR` instead.
Next: jig-typescript (typescript-lsp; biome or eslint+prettier detected per repo; tsc + vitest/npm test on Stop), then jig-go, then the task-runner fallback.
Blockers: none (marketplace URL still undecided).

## 2026-09-23 — claude (Claude Code, Phase 2: jig-go, built by a subagent)
Done:
- New plugin `jig-go` 0.1.0 (depends on `gopls-lsp@claude-plugins-official`):
  - PostToolUse `go-post-edit.sh`: `goimports -w` (fallback `gofmt -w`) from the module root; syntax errors → exit 2 (file untouched). The file is recorded for Stop. No golangci-lint on edit: it type-checks whole packages (seconds per edit) and gopls already reports compile/vet errors after each edit.
  - Stop `go-stop-check.sh`: per module (nearest go.mod, not above the git root), on the edited packages only: `golangci-lint run` (repo `.golangci.yml`; `go vet` if golangci-lint is missing), then `go test`. `-mod=readonly` (`-mod=vendor` with vendor/modules.txt) on the command line, so go.mod/go.sum never change. Blocks once. A config golangci-lint cannot load (v1 format) and missing tools only warn.
  - SessionStart `check-tools.sh` (go, gopls, goimports, golangci-lint).
  - Path-scoped `go-conventions` skill.
- Repo stays clean: Go caches in GOCACHE, `GOLANGCI_LINT_CACHE` in the plugin data dir, no test binaries or coverage.
- Fixture `tests/fixtures/go-sample` (no dependencies, golangci-lint v2 config); `tests/go-hooks.bats` (25 tests).
- Harness mise.toml pins golangci-lint 2.13.2, gopls 0.23.0 and goimports 0.50.0 (go 1.27.1 already there). jig-init pins them for Go repos (go written once for tf + go) and adds a gofmt check + `golangci-lint run ./...` to lint (root module only; multi-module repos add their own entries).
- Smoke (`claude -p --plugin-dir plugins/jig-go`, `gopls-lsp` installed at project scope in a throwaway copy): LSP goToDefinition on `ErrDivByZero` → `calc.go:7:5`; goimports reformatted the badly formatted `Add`; the Stop hook blocked once on the failing `TestAdd`; Claude fixed it. Uninstalled afterwards.
Findings:
- golangci-lint v2 exits 1 for issues (compile errors appear as `typecheck`), 3 for an unloadable config (v1 config: "unsupported version of the configuration"), 5 for a dir without Go files.
- **The fix after a block is never re-checked in the same stop cycle** (all stack plugins): the stop with `stop_hook_active=true` is skipped, so a wrong fix ends a `-p` run unchecked. Open design question.
- mise's aqua backend can time out (3 s) fetching golangci-lint from api.github.com; `MISE_FETCH_REMOTE_VERSIONS_TIMEOUT=30s` fixes it.
- Possible follow-up: jig-init could place a starter `.golangci.yml` (v2) for Go repos that have none.

## 2026-09-23 — claude (Claude Code, Phase 2: jig-typescript, built by a subagent)
Done:
- New plugin `jig-typescript` 0.1.0 (depends on `typescript-lsp@claude-plugins-official`):
  - PostToolUse `ts-post-edit.sh` on .ts/.tsx/.mts/.cts/.js/.jsx/.mjs/.cjs. Linter detected per repo (nearest config): `biome.json` → `biome check --write` (errors block, warnings don't); eslint config → `prettier --write` (only if the repo uses prettier) + `eslint --fix`; else prettier if used. Repo ignore files apply. If eslint itself crashes, the user gets a message and the edit is not blocked. The file is recorded for Stop.
  - Stop `ts-stop-check.sh`: `tsc --noEmit` per nearest tsconfig.json (errors only), then tests per package: `vitest run --no-cache --passWithNoTests` when vitest is used, else `npm|pnpm|yarn test` / `bun run test` (from the lockfile or `packageManager`) when `scripts.test` is not npm's stub. `CI=true`. Blocks once. Never installs packages.
  - SessionStart `check-tools.sh`: missing tools, missing node_modules, missing tsserver.
  - Path-scoped `typescript-conventions` skill.
- Tools resolve from `node_modules/.bin` (package, then ancestors) before PATH.
- Repo stays clean: `--tsBuildInfoFile` in the plugin data dir (`--noEmit` still writes tsbuildinfo for incremental/composite projects), vitest `--no-cache`.
- Fixture `tests/fixtures/ts-sample` (biome, vitest); bats toggles it to eslint(+prettier). Offline: setup symlinks node_modules/{typescript,vitest} to the mise installs. 35 tests.
- Harness mise.toml pins npm:typescript 6.0.3, typescript-language-server 6.0.0, @biomejs/biome 2.5.14, eslint 10.11.0, prettier 3.9.8, vitest 5.0.1.
- jig-init: detects biome vs eslint and prettier at init. It pins typescript-language-server + typescript, plus biome, or eslint (+ prettier), and adds `biome ci .`, or `eslint .` (+ `prettier --check .`), plus `tsc --noEmit` when tsconfig.json exists. node is pinned once. It reminds the user to run the package install.
- Smoke (`claude -p --plugin-dir plugins/jig-typescript`, typescript-lsp installed at project scope): LSP goToDefinition OK; biome reformatted the edit; the LSP flagged TS2322 right after the edit; Stop blocked once with the tsc error; Claude fixed it. Uninstalled afterwards.
Decision (subagent, accepted by lead): in eslint repos, prettier runs only when the repo uses it, so we never impose a style on eslint-formatted repos.
Findings:
- **TypeScript 7 ships no tsserver**, and typescript-language-server 6.0.0 (official typescript-lsp) only looks in the project's `node_modules/typescript`. So the LSP needs TS ≤ 6 installed in the project. We pin 6.0.3. Revisit when the official plugin moves to TS 7's native LSP.
- eslint 10 dropped `.eslintrc*`: legacy-config repos need their own older eslint in node_modules (resolved first); otherwise the user gets a message.
- vitest writes `node_modules/.vite/vitest/.../results.json` unless run with `--no-cache` (not controllable when the repo's `npm test` calls vitest).
Next: task-runner fallback (last Phase 2 item); decide on re-checking fixes when `stop_hook_active` (see jig-go findings).
Blockers: none (marketplace URL still undecided).

## 2026-09-23 — claude (Claude Code, Stop re-check)
Decision (human): the stack Stop hooks re-check Claude's fix instead of skipping the stop that follows a block.
Done:
- jig-terraform, jig-python, jig-typescript and jig-go Stop hooks: when `stop_hook_active` is true they still run the checks for the files edited in the session. If the fix is clean, they clear the list silently. If checks still fail, they show a `systemMessage` ("checks still fail after Claude's fix (not blocking twice)") with the failures, don't block, and keep the list so the next stop checks again. So a Stop hook never blocks twice in a row, and a bad fix no longer ends a `-p` run unchecked.
- Tests: in each suite, the `stop true` case now expects the report (no `decision`), and a new case expects a clean re-check to be silent and clear the list. Rule added to CLAUDE.md, READMEs updated. The four plugins are bumped to 0.1.1 (plugin.json + marketplace.json).
Note: jig-core's require-progress keeps its plain skip on `stop_hook_active` (it only asks for a progress note; nothing to re-check).
Next: task-runner fallback (last Phase 2 item).
