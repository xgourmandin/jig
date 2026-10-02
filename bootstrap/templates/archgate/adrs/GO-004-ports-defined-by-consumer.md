---
id: GO-004
title: Interfaces are defined by the consumer, not by adapters
domain: go
rules: true
files: ["**/*.go"]
---

# Interfaces are defined by the consumer, not by adapters

## Context
Go interfaces are satisfied implicitly, so the interface belongs where it is used. An adapter that exports its own interface for others to depend on inverts the dependency again: callers couple to the adapter's shape.

## Decision
Non-test files in `internal/adapters/` do not declare exported interface types. Ports live in `internal/ports/` (I/O the app needs) or next to their consumer in `internal/domain` / `internal/app`. Adapters expose concrete types and constructors (accept interfaces, return structs). Unexported interfaces (for faking the adapter's own client) are fine. See GO-001 for the layout.

Opt out for one type with `// archgate-ignore GO-004/adapters-do-not-define-ports <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- `package ports; type OrderRepository interface { Save(ctx context.Context, o domain.Order) error }`, implemented by `postgres.OrderRepo`.
### Don't
- `package postgres; type Repository interface { ... }` that the app then imports.

## Consequences
Interfaces stay small and shaped by their callers. Rule `adapters-do-not-define-ports` in `GO-004-ports-defined-by-consumer.rules.ts`.
