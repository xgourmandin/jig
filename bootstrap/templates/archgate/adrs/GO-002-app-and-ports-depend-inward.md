---
id: GO-002
title: Application and ports depend inward only
domain: go
rules: true
files: ["**/*.go"]
---

# Application and ports depend inward only

## Context

Dependencies in a hexagonal layout point toward the domain. If a use case imports a concrete adapter, swapping or faking the adapter means editing business code.

## Decision

Non-test files under `internal/app/` and `internal/ports/` do not import `internal/adapters`, `cmd`, or the infrastructure and framework packages listed in GO-001. `internal/ports/` additionally does not import `internal/app` (ports depend on the domain only). The app may import the domain and the ports. See GO-001 for the layout.

Opt out for one import with `// archgate-ignore GO-002/app-and-ports-depend-inward <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- A use case takes a port (`ports.OrderRepository`) in its constructor.
- Use `context`, `errors`, `time`, and other pure standard library packages freely.

### Don't

- `internal/app` importing `internal/adapters/postgres`
- A port signature that exposes `*sql.Rows` or `*http.Request`; use domain types.

## Consequences

Use cases are tested with in-memory fakes of ports. Rule `app-and-ports-depend-inward` in `GO-002-app-and-ports-depend-inward.rules.ts`.
