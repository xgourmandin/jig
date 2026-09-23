# jig-terraform

Enable in repos that contain Terraform.

| Component | File | What it does |
|---|---|---|
| LSP | `.lsp.json` | Wires `terraform-ls` into Claude Code's LSP tool (definitions, references, diagnostics) |
| Edit checks (PostToolUse) | `hooks/scripts/tf-post-edit.sh` | `terraform fmt` + `tflint` on every edited `.tf`, problems fed back to Claude |
| Tool check (SessionStart) | `hooks/scripts/check-tools.sh` | Tells Claude which binaries are missing |
| Skill | `skills/tf-plan-review` | Plan-only risk review |

Requires `terraform`, `terraform-ls`, `tflint`, `jq` on PATH (install via the repo's `mise.toml`).
