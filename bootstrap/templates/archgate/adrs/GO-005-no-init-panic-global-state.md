---
id: GO-005
title: No init(), panic or global mutable state in library code
domain: go
rules: true
files: ["**/*.go"]
---

# No init(), panic or global mutable state in library code

## Context
`init()` runs at import time in an order nobody controls, `panic` takes the whole process down from inside a dependency, and package-level variables make tests order-dependent and goroutines racy.

## Decision
Non-test Go files that are not `package main` (library code) have:
- no `func init()` (rule `no-init`);
- no call to `panic(` (rule `no-panic`); return an error;
- no package-level `var` (rule `no-global-mutable-state`), except error sentinels (`ErrFoo`, `errFoo`), `_` interface assertions, variables initialised with `errors.New`, `regexp.MustCompile` or `template.Must`, and `//go:embed` variables. State belongs in a struct built by a constructor.

`package main` files (binaries, `cmd/`) and `_test.go` files are not checked. Opt out for one site with `// archgate-ignore GO-005/<rule> <reason>` (`<rule>` is `no-init`, `no-panic` or `no-global-mutable-state`) on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- `var ErrNotFound = errors.New("not found")`
- `func NewService(repo ports.Repo, clock Clock) *Service`
### Don't
- `var db *sql.DB` set from `init()`
- `panic(err)` on a failed lookup

## Consequences
Libraries are explicit about their dependencies and safe to embed. The rules are line-based on gofmt'd code; they do not catch state hidden in a `var` of a function type or a map built elsewhere. golangci-lint's `gochecknoinits` and `gochecknoglobals` cover the same ground more precisely if a repo prefers them (GO-009). Rules in `GO-005-no-init-panic-global-state.rules.ts`.
