---
id: TF-002
title: Child modules do not configure providers or backends
domain: terraform
rules: true
files: ["**/*.tf"]
---

# Child modules do not configure providers or backends

## Context

A provider or backend block inside a reusable module forces every caller to inherit that configuration, and makes the module impossible to use with `count`, `for_each` or `depends_on`. Only root modules know which account, region and state to use.

## Decision

Modules under a `modules/` directory declare `required_providers` (minimum versions) but never contain `provider`, `backend` or `cloud` blocks. Callers configure providers in the root module and pass aliases with `providers = { ... }`. Runnable examples under `examples/` and `tests/` are root modules and are exempt.

Opt out for one block with a comment `# archgate-ignore TF-002/no-provider-or-backend-in-child-module <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- `terraform { required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } } }` in `modules/net/versions.tf`
- Configure `provider "aws" { region = ... }` in `live/<env>/.../providers.tf`

### Don't

- `provider "aws" { region = "eu-west-1" }` in `modules/net/main.tf`
- `backend "s3" {}` in a module

## Consequences

Modules stay reusable and composable. Rule `no-provider-or-backend-in-child-module` in `TF-002-no-provider-in-child-modules.rules.ts` fails `archgate check` on violations.
