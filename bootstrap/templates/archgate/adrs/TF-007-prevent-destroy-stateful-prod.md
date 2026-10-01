---
id: TF-007
title: Stateful resources in production roots have prevent_destroy
domain: terraform
rules: true
files: ["**/*.tf"]
---

# Stateful resources in production roots have prevent_destroy

## Context
Databases, buckets, KMS keys and DNS zones hold data or identity that cannot be recreated from code. One bad rename or a removed block would delete them.

## Decision
In production root modules (a directory path containing `prod`, `production` or `prd`), resources of known stateful types set `lifecycle { prevent_destroy = true }`. Use the provider's deletion protection too. Resources inside shared modules are not checked here; modules should expose a variable for it. The checked types are listed in the rule file.

Opt out for one block with a comment `# jig:allow TF-007 <reason>` on the line before it or inside it. The reason is required.

## Do's and Don'ts
### Do
- `lifecycle { prevent_destroy = true }` plus `deletion_protection = true` on `aws_db_instance.this`
- `# jig:allow TF-007 reporting replica, rebuilt nightly` when the data is truly disposable
### Don't
- A production database, bucket or KMS key without `prevent_destroy`
- `prevent_destroy = false` to get a plan through

## Consequences
Destroying production data needs a deliberate, reviewed edit that removes the guard first. Rule `stateful-resource-prevent-destroy` in `TF-007-prevent-destroy-stateful-prod.rules.ts`.
