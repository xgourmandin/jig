# Spec: bootstrap the ACME Claude Code harness

**Goal:** a working v0.1.0 of the company marketplace that the pilot team can enable on one infra repo and one mixed repo.

**Scope:** acme-core, acme-terraform, acme-python, acme-typescript, acme-go, bootstrap `acme-init`, harness CI.
**Out of scope:** reviewer subagents, cost tooling, cloud-session support, languages beyond the three.

## Acceptance criteria
- `claude plugin validate` passes for every plugin; `mise run test` and `mise run lint` are green.
- In a sample repo, loading the plugins shows: session context from `.ai/work/<branch>/`; blocked `terraform apply`; fmt/lint feedback after editing a `.tf`; LSP go-to-definition working for Terraform and one language.
- `acme-init` on a fresh repo detects the stack and writes `.claude/settings.json`, `mise.toml`, `CLAUDE.md` skeleton, and installs plugins at project scope.
- The repo map (codebase-memory-mcp) is queryable over MCP and bootstraps from a committed snapshot in < 5 s on a medium repo.
- `archgate check` runs in `mise run lint` and fails on an ADR violation.
- Every hook has bats tests (allow + block cases).

## Constraints
- Glue only; reuse OSS tools (see DESIGN.md).
- Hooks deterministic (bash + jq). Guardrails fail closed.
- Never apply infrastructure.

## Open questions (ask the human before the related phase)
1. Company name to replace the "acme" placeholder, and the Git URL that will host this marketplace.  *(Phase 0)*
2. Terraform or OpenTofu (or both)? Which cloud providers? Are read-only credentials available for `plan`, or must we use `-backend=false`?  *(Phase 1)*
3. Existing CI/pre-commit setup to align with: lefthook, pre-commit, or none?  *(Phase 1)*
4. Ticket system (Jira, Linear, GitHub/GitLab issues) for linking work state.  *(Phase 1)*
5. Python: pyright or mypy? uv or poetry? TypeScript: biome or eslint+prettier? Test runners?  *(Phase 2)*
6. Claude plan (Team/Enterprise) and whether admins will push managed settings.  *(Phase 3)*
