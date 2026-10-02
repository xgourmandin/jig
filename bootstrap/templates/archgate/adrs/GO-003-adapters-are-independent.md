---
id: GO-003
title: Adapters never depend on each other
domain: go
rules: true
files: ["**/*.go"]
---

# Adapters never depend on each other

## Context

Adapters sit at the outer edge and depend inward (domain, ports). When one adapter imports another, replacing or removing one silently breaks the other, and the dependency graph hides a flow that should go through the application.

## Decision

A non-test file in `internal/adapters/<a>/` does not import `internal/adapters/<b>` for `b != a`, nor anything under `cmd`. Adapters may import `internal/domain`, `internal/ports` and `internal/app` types they implement or accept. If two adapters need to cooperate, the use case in `internal/app` calls both through ports. Shared technical code (e.g. a retry helper) goes in its own neutral package outside `internal/adapters`. See GO-001 for the layout.

Opt out for one import with `// archgate-ignore GO-003/adapters-are-independent <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- `internal/adapters/http` calls `app.PlaceOrder`; the app uses the `ports.Payments` port implemented by `internal/adapters/stripe`.

### Don't

- `internal/adapters/http` importing `internal/adapters/postgres` to read a row directly.

## Consequences

Each adapter can be deleted or replaced alone. Rule `adapters-are-independent` in `GO-003-adapters-are-independent.rules.ts`. Files directly in `internal/adapters/` (no sub-package) are not treated as an adapter.
