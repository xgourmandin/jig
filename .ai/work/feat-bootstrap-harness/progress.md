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
