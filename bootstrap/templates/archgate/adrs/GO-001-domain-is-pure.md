---
id: GO-001
title: The domain package imports no adapters, frameworks or infrastructure
domain: go
rules: true
files: ["**/*.go"]
---

# The domain package imports no adapters, frameworks or infrastructure

## Context

We build Go services as hexagonal architecture (ports and adapters): business rules in the middle, I/O at the edges. Once `internal/domain` imports `net/http`, `database/sql` or an SDK, the rules can no longer be tested or reasoned about without that infrastructure.

## Decision

The layout this and the other GO ADRs assume:

- `internal/domain/`: entities, value objects, domain services. Pure Go.
- `internal/app/`: use cases. Orchestrates domain objects through ports.
- `internal/ports/`: the interfaces (I/O ports) the app needs from the outside world.
- `internal/adapters/<name>/`: implementations of ports (HTTP, SQL, queues, cloud SDKs). One package per technology.
- `cmd/<binary>/`: composition root (GO-008).

Non-test files under `internal/domain/` do not import: `internal/app`, `internal/ports`, `internal/adapters`, `cmd`, `net`, `net/http`, `os`, `os/exec`, `database/sql`, or the known framework and SDK packages listed in the rule file (ORMs, SQL drivers, cloud SDKs, web frameworks, gRPC, Redis, Kafka, cobra). If the domain needs something from outside, it defines an interface (GO-004) and an adapter implements it.

Opt out for one import with `// archgate-ignore GO-001/domain-is-pure <reason>` on the line before it. The reason is required, without one the violation stays. Test files are not checked.

## Do's and Don'ts

### Do

- Keep `internal/domain` to the standard library's pure parts (`errors`, `fmt`, `time`, `strings`, ...).
- Pass time, IDs and randomness in through small domain-defined interfaces.

### Don't

- `import "database/sql"` or `import "net/http"` in `internal/domain`
- Struct tags and types from an ORM on domain entities; map in the adapter.

## Consequences

Domain tests run without servers or fakes of third-party SDKs. Rule `domain-is-pure` in `GO-001-domain-is-pure.rules.ts`. It checks import paths only; it does not detect a domain type that merely wraps an infrastructure value.
