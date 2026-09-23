# Progress

## 2026-09-23 — claude (claude.ai, design session)
Done: design agreed (docs/DESIGN.md). Scaffolded marketplace with acme-core (guard, session-start, require-progress hooks; start-work and handoff skills) and acme-terraform (terraform-ls .lsp.json, fmt/tflint PostToolUse hook, tool check, tf-plan-review skill), bootstrap/detect-stack.sh, bats tests for guard.sh (13/13 passing), shellcheck clean.
Decisions: bash+jq hooks for determinism; guardrail fails closed if jq missing; work state keyed by branch name; hooks.json uses the `{"hooks": {...}}` wrapper.
Not yet verified: `claude plugin validate`, terraform-ls LSP wiring and hooks inside a real Claude Code session (no Claude Code or terraform binaries in the design environment).
Next: Phase 0, task 1 — ask the human for the company name and Git host URL.
Blockers: open questions in spec.md.
