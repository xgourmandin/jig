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
