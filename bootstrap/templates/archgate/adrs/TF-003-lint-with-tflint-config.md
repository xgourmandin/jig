---
id: TF-003
title: Terraform style is enforced by the shared tflint config
domain: terraform
rules: false
files: ["**/*.tf"]
---

# Terraform style is enforced by the shared tflint config

## Context
Naming, documentation and layout rules are mechanical and tflint already checks them. Re-implementing them as Archgate rules would duplicate a maintained tool.

## Decision
`.tflint.hcl` at the repo root (copied by `jig-init`) is the single source of style rules. It runs on every edit (jig-terraform hook, nearest `.tflint.hcl` up the tree), in `mise run lint` (`tflint --recursive --config "$PWD/.tflint.hcl"`) and in CI. It enforces:
- snake_case names for every block label, variable, output and local (`terraform_naming_convention`)
- a `description` on every variable and output, and a `type` on every variable (`terraform_documented_*`, `terraform_typed_variables`)
- `required_version` and provider `required_providers` constraints (`terraform_required_version`, `terraform_required_providers`)
- standard module files: variables in `variables.tf`, outputs in `outputs.tf` (`terraform_standard_module_structure`)
- pinned module sources, no unused declarations, `#` comments (`terraform_module_pinned_source`, `terraform_unused_declarations`, `terraform_comment_syntax`)

Fix findings rather than disabling rules. A rule that a repo must relax is changed in that repo's `.tflint.hcl` with a comment saying why, or a single finding gets `# tflint-ignore: <rule> <reason>`.

## Do's and Don'ts
### Do
- `variable "disk_size_gib" { type = number, description = "Root disk size in GiB." }`
- Keep `.tflint.hcl` in the repo root so editors, hooks and CI share it
### Don't
- Remove a rule from `.tflint.hcl` to make one change pass
- `# tflint-ignore` without a reason

## Consequences
One config, one place to tune. Rules Jig wants beyond tflint's built-ins go in TF-002, TF-006, TF-007 and TF-009 (Archgate rules). Security checks stay with trivy.
