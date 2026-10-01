# jig-terraform

Enable in repos that contain Terraform or OpenTofu.

| Component | File | What it does |
|---|---|---|
| LSP | `.lsp.json` | Wires `terraform-ls` into Claude Code's LSP tool (definitions, references, diagnostics) |
| Edit checks (PostToolUse) | `hooks/scripts/tf-post-edit.sh` | `fmt` + `tflint` on every edited `.tf`, problems fed back to Claude; records the module for Stop |
| Validate (Stop) | `hooks/scripts/tf-stop-validate.sh` | Offline `init -backend=false` + `validate` on modules edited this session; blocks once on errors (the re-check after Claude's fix only reports, never blocks twice). `.terraform/` goes to the plugin data dir and the lock file is restored, so the repo is untouched |
| Tool check (SessionStart) | `hooks/scripts/check-tools.sh` | Tells Claude which binaries are missing |
| Skill | `skills/terraform-conventions` | Jig writing conventions (layout, naming, variables, expressions, secrets, safety, tests), loaded automatically for `.tf`/`.tfvars`/`.tftest.hcl` files; details and examples in `writing.md`, read on demand |
| Skill | `skills/terraform-architecture` | Module levels, splitting state into stacks, environments, cross-stack data, module versioning, repo layout |
| ADRs (templates) | `bootstrap/templates/archgate/adrs/TF-*`, `bootstrap/templates/tflint/.tflint.hcl` | Copied by `jig-init`: TF-001/002/006/007/009 with Archgate rules, TF-003 documents the shared tflint config. Enforced by `archgate check` in `mise run lint`; exceptions via `# jig:allow TF-00X <reason>` |
| Skill | `skills/tf-plan-review` | Plan-only risk review (prefers the CI plan) |
| Registry docs (MCP) | `.mcp.json`, `scripts/terraform-mcp.sh` | HashiCorp terraform-mcp-server, `registry` toolset only (public provider/module docs, no HCP/TFE operations, no token) |

**Terraform or OpenTofu.** Hooks use `tofu` when the repo has `.opentofu-version` or pins `opentofu` in `mise.toml`, else `terraform`. Override with `JIG_TF_BIN`.

**Repo-specific conventions** go in the consuming repo's `.claude/rules/terraform.md` (with `paths: ["**/*.tf"]` frontmatter), written by `jig-init`. Plugins cannot ship rules, so shared conventions live in the skill.

Requires `terraform` or `tofu`, `terraform-ls`, `tflint`, `jq` on PATH; optional `trivy`, `terraform-mcp-server` (all via the repo's `mise.toml`, written by `jig-init`).

**Repo lint task.** When the repo defines a mise `lint` task (and mise is installed), jig-core runs `mise run lint` on Stop, the same check as CI, and this plugin skips `trivy` on Stop. Without one, it calls the tool directly.
