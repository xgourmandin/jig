---
id: TF-006
title: Root modules commit .terraform.lock.hcl
domain: terraform
rules: true
files: ["**/*.tf"]
---

# Root modules commit .terraform.lock.hcl

## Context

Without a committed dependency lock file, `init` picks the newest provider matching the constraint, so a plan can differ between laptops and CI.

## Decision

Every root module (a directory outside `modules/`, `examples/` and `tests/` that has a `provider` block or a `backend`/`cloud` block) has a `.terraform.lock.hcl` next to it, committed to Git and not git-ignored. Provider constraints in root modules use `~>`; tflint (TF-003) checks that constraints exist.

Opt out for one block with a comment `# archgate-ignore TF-006/root-module-has-lock-file <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- Commit `.terraform.lock.hcl` after `init -upgrade` and review the diff
- Generate hashes for every platform CI and developers use: `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`

### Don't

- Add `.terraform.lock.hcl` to `.gitignore`
- Delete the lock file to "fix" a provider conflict

## Consequences

Provider upgrades are explicit, reviewed changes. Rule `root-module-has-lock-file` in `TF-006-root-modules-commit-lock-file.rules.ts`.
