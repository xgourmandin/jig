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
Blockers: marketplace Git URL still undecided (real `claude plugin install` from jig-init untested).
