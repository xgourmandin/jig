---
name: tf-plan-review
description: Review a Terraform plan for risk before a human or CI applies it. Use when the user asks to "review the plan", "is this plan safe", or after changing Terraform code that will be applied.
---

# Terraform plan review

Never run `apply`. Produce a plan and review it.

1. In the module directory, run `terraform init -input=false` (use `-backend=false` if no read-only credentials are available and say so), then `terraform plan -input=false -out=tfplan` and `terraform show -json tfplan > tfplan.json`.
2. Summarize with `jq` over `.resource_changes[]`, grouping by action (`create`, `update`, `delete`, `delete+create` = replace). Count each.
3. Flag as HIGH risk: any delete or replace of stateful resources (databases, buckets, disks, KMS keys, DNS zones), IAM/policy changes, security-group or firewall rules opening `0.0.0.0/0`, changes to `prevent_destroy` or `lifecycle` blocks.
4. For each replace, name the attribute that forces replacement (`.change.replace_paths`).
5. Output: a short table (address, action, risk, reason), then a one-line verdict. Delete `tfplan` and `tfplan.json` afterwards; they may contain secrets.
