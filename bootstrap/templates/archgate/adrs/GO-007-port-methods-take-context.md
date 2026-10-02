---
id: GO-007
title: Port methods take context.Context first
domain: go
rules: true
files: ["**/*.go"]
---

# Port methods take context.Context first

## Context

Ports are the I/O boundary. Without a `context.Context`, adapters cannot honour cancellation, deadlines or tracing, and callers cannot stop a slow database or HTTP call.

## Decision

Every method of every interface declared in `internal/ports/` (non-test files) has `context.Context` as its first parameter. By convention `internal/ports/` holds I/O ports only; pure collaborators (clock, ID generator, hasher) are defined next to their consumer in domain/app and are not checked. See GO-001 for the layout.

Opt out for one method with `// archgate-ignore GO-007/port-methods-take-context <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- `Save(ctx context.Context, o domain.Order) error`

### Don't

- `Save(o domain.Order) error` in a port
- Storing the context in a struct to work around a missing parameter.

## Consequences

Cancellation reaches every adapter. Rule `port-methods-take-context` in `GO-007-port-methods-take-context.rules.ts`; embedded interfaces are not followed.
