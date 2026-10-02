---
id: GO-006
title: Wrap errors with %w, never ignore them silently
domain: go
rules: true
files: ["**/*.go"]
---

# Wrap errors with %w, never ignore them silently

## Context

`fmt.Errorf("...: %v", err)` flattens the error to a string, so `errors.Is` and `errors.As` stop working up the stack. A bare `_ = f()` hides failures with no record of why that was fine.

## Decision

In non-test Go files:

- `fmt.Errorf` calls that take a variable named `err` wrap it with `%w` (rule `wrap-errors-with-w`);
- a statement `_ = call(...)` (or `_, _ = call(...)`) carries a `//` comment on the same or the previous line saying why the error is ignored (rule `no-ignored-errors`).

Opt out with `// archgate-ignore GO-006/<rule> <reason>` (`<rule>` is `wrap-errors-with-w` or `no-ignored-errors`) on the line before it. The reason is required, without one the violation stays. The wider "unchecked error" analysis (`errcheck`, `errorlint`) stays with golangci-lint (GO-009); this rule only covers what a line scan can see.

## Do's and Don'ts

### Do

- `return fmt.Errorf("load order %s: %w", id, err)`
- `_ = f.Close() // read-only file, nothing to flush`

### Don't

- `return fmt.Errorf("load order: %v", err)`
- `_ = tx.Rollback()`

## Consequences

Callers can branch on sentinel and typed errors. Rules in `GO-006-errors-wrapped-not-ignored.rules.ts`.
