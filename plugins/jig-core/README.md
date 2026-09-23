# jig-core

Always enabled in every Jig repo.

| Component | File | What it does |
|---|---|---|
| Guardrails (PreToolUse) | `hooks/scripts/guard.sh` | Blocks terraform/tofu apply/destroy/import, state mutation, force-push, `rm -rf /`, and access to `.env`, `*.tfstate`, key material. The IaC checks live here, not in jig-terraform, so they apply whichever stack plugins a repo enables |
| Session context (SessionStart) | `hooks/scripts/session-start.sh` | Injects branch, plan status and last progress entry from `.ai/work/<branch>/`. After compaction (source `compact`) it also re-injects the current plan phase |
| Progress enforcement (Stop) | `hooks/scripts/require-progress.sh` | Asks Claude once to update plan/progress when code changed but work state did not |
| Repo map (MCP) | `.mcp.json`, `scripts/repo-map-mcp.sh` | codebase-memory-mcp as MCP server `repo-map` (stdio, reads limited to the project). Pilot: security review pending |
| Repo map status (SessionStart) | `hooks/scripts/repo-map-status.sh` | One line: graph size and age, or how to index |
| Skills | `skills/start-work`, `skills/handoff` | Create / update the per-branch work state |
| Skill | `skills/navigate-code` | Repo map → LSP → ast-grep → grep |
| Skill | `skills/adrs` | Read ADRs before coding (`archgate review-context`), `archgate check` after, propose new ADRs |

Requires `git` and `jq` on PATH; `codebase-memory-mcp` and `archgate` from the repo's `mise.toml` (see `bootstrap/jig-init`).
