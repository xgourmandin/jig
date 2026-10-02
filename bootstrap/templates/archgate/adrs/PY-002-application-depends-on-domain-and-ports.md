---
id: PY-002
title: Application and ports depend only inward
domain: python
rules: true
files: ["**/*.py"]
---

# Application and ports depend only inward

## Context
Use cases orchestrate the domain through ports. If they import an adapter or a framework they become tied to one technology and need it in every test.

## Decision
Modules in `src/<pkg>/application/` and `src/<pkg>/ports/` import the standard library, the domain, ports and application modules only. They never import `<pkg>.adapters`, `<pkg>.bootstrap`, `<pkg>.entrypoints` or an infrastructure/framework package. Concrete adapters are created and injected only in the composition root, the `bootstrap` package (or `entrypoints` for the process entry), so no other layer can reach them.

Layout assumed: `src/<pkg>/{domain,application,ports,adapters,bootstrap,entrypoints}/`. Files elsewhere (for example `tests/`) are not layer-checked. Layers are found from the path, imports from the code (`import x`, `from x import y`, relative imports resolved).

Opt out for one import with `# archgate-ignore PY-002/application-depends-inward-only <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- Take a port in the constructor: `def __init__(self, orders: OrderRepository)`
- Build `PlaceOrder(PostgresOrderRepository(...))` in `bootstrap`
### Don't
- `from shop.adapters.postgres import PostgresOrderRepository` in a use case
- `import requests` in the application layer

## Consequences
Use cases are tested with in-memory fakes. Rule `application-depends-inward-only` in `PY-002-application-depends-on-domain-and-ports.rules.ts`.
