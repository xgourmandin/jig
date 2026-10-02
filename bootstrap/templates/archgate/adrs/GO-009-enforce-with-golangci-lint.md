---
id: GO-009
title: Back the architecture rules with golangci-lint
domain: go
rules: false
files: ["**/*.go", "**/.golangci.y*ml"]
---

# Back the architecture rules with golangci-lint

## Context

The `.rules.ts` checks of GO-001..GO-008 scan lines of gofmt'd code and import paths. Linters understand types and run in the editor, so each check is best enforced at the cheapest layer that can do it properly.

## Decision

This ADR is documentation only (no `.rules.ts`). The repo's `.golangci.yml` (v2 format) enables, in addition to the defaults: `errcheck` and `errorlint` (unchecked and unwrapped errors, complements GO-006), `contextcheck` (complements GO-007), `gochecknoinits` and `gochecknoglobals` (complements GO-005), and `depguard` with one rule per layer that mirrors GO-001..GO-003 for the repo's own dependency list (e.g. deny `gorm.io` in `**/internal/domain/**`). `mise run lint` runs both golangci-lint and `archgate check`, so a violation is caught by whichever sees it first.

Style (naming, formatting, comments) is left entirely to golangci-lint and gofmt; no ADR duplicates it.

## Do's and Don'ts

### Do

- Add a `depguard` rule when the repo adopts a new framework that the domain must never import.

### Don't

- Silence a linter with `//nolint` instead of fixing the code or recording an exception with a reason.

## Consequences

Two independent checks for the architecture boundaries, so a gap in one rarely lets a violation through.
