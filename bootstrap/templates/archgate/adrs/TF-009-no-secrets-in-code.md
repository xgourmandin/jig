---
id: TF-009
title: No secrets in tfvars, defaults or code
domain: terraform
rules: true
files: ["**/*.tf", "**/*.tfvars"]
---

# No secrets in tfvars, defaults or code

## Context
State and plan files hold plaintext values, and Git history is forever. `sensitive = true` only hides values from CLI output.

## Decision
Committed `.tfvars` files and `.tf` files hold no secret values (passwords, tokens, API or access keys, private keys). Variables whose name looks like a secret set `sensitive = true` (or `ephemeral = true`) and have no default. Secrets are read at apply time from a secrets manager; on Terraform/OpenTofu 1.11+ prefer ephemeral resources and write-only arguments. The name check skips names ending in `_arn`, `_id`, `_name`, `_path`, `_file`, `_url`, `_ttl`, `_seconds`, `_version`.

Opt out for one block with a comment `# archgate-ignore TF-009/<rule> <reason>` (`<rule>` is `no-secret-values` or `secret-variables-sensitive`) on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- `variable "db_password" { type = string, sensitive = true }` with no default
- `variable "db_password_secret_arn" { type = string }` pointing at a secrets manager entry
### Don't
- `db_password = "hunter2"` in `terraform.tfvars`
- A secret variable without `sensitive`, or with a default
- Access key ids (`AKIA...`) or `-----BEGIN PRIVATE KEY-----` in any `.tf` or `.tfvars` file

## Consequences
Secrets stay out of Git. trivy (Stop hook and CI) scans for secrets too, with a wider pattern set. Rules `no-secret-values` and `secret-variables-sensitive` in `TF-009-no-secrets-in-code.rules.ts`.
