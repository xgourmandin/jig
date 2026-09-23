# acme-core

Always enabled in every ACME repo.

| Component | File | What it does |
|---|---|---|
| Guardrails (PreToolUse) | `hooks/scripts/guard.sh` | Blocks terraform apply/destroy/import, state mutation, force-push, `rm -rf /`, and access to `.env`, `*.tfstate`, key material |
| Session context (SessionStart) | `hooks/scripts/session-start.sh` | Injects branch, plan status and last progress entry from `.ai/work/<branch>/` |
| Progress enforcement (Stop) | `hooks/scripts/require-progress.sh` | Asks Claude once to update plan/progress when code changed but work state did not |
| Skills | `skills/start-work`, `skills/handoff` | Create / update the per-branch work state |

Requires `git` and `jq` on PATH.
