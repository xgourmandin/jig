---
name: terraform-conventions
description: Jig conventions for writing Terraform/OpenTofu code (layout, naming, variables, providers, security). Loaded automatically when working on .tf/.tfvars files.
paths:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/*.tofu"
user-invocable: false
---

# Terraform / OpenTofu conventions (Jig)

Company-wide defaults. A repo's own `.claude/rules/terraform.md` or ADRs in `.archgate/adrs/` override them.

**Binary.** Use `tofu` if the repo has `.opentofu-version` or pins `opentofu` in `mise.toml`, otherwise `terraform`. Never run `apply`, `destroy`, `import` or `state` mutations: CI applies (the guard blocks them). Validate offline: `init -backend=false`, then `validate`. The Stop hook does this for modules you edited.

**Layout.** One module per directory: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf` (plus `locals.tf`/`data.tf` when large). Root modules (per environment) only compose child modules and set providers/backends. Child modules never configure providers or backends.

**Naming.** snake_case everywhere. Resource names describe the role, not the type (`aws_s3_bucket.artifacts`, not `aws_s3_bucket.bucket`). Use `this` for the single main resource of a module.

**Variables and outputs.** Every variable has `type` and `description`. Add `validation` blocks for constrained inputs. Mark secrets `sensitive = true` and never give them defaults. Every output has a `description`. Prefer objects over many loose variables for related settings.

**Versions.** Pin `required_version` and every provider in `required_providers` with `~>` constraints. Commit `.terraform.lock.hcl` for root modules. Pin module sources to a tag or version, never a branch.

**Iteration.** Prefer `for_each` with stable keys over `count` (count only for 0/1 toggles). Don't key `for_each` on values unknown until apply.

**Safety.** Stateful resources (databases, buckets, KMS keys, DNS zones) get `lifecycle { prevent_destroy = true }` in production roots. Renames use `moved` blocks, not state commands. No `0.0.0.0/0` ingress, public buckets or wildcard IAM actions without an explicit comment explaining why.

**Finding things.** Use the LSP (go to definition/references on `module.x`, `var.y`) before grepping. Use registry docs (terraform MCP server, if enabled) for provider arguments instead of guessing.
