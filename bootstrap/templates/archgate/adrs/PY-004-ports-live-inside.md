---
id: PY-004
title: Ports are interfaces owned by the inside
domain: python
rules: true
files: ["**/*.py"]
---

# Ports are interfaces owned by the inside

## Context

The inside defines what it needs (ports); adapters implement them. An interface declared in an adapter inverts that: the core ends up depending on the adapter to name its own dependency.

## Decision

Ports are `typing.Protocol` (preferred) or `abc.ABC` classes defined in `src/<pkg>/ports/` (or the domain/application). Adapters implement them but never declare a `Protocol`/`ABC` class themselves. In `ports/`, a class whose name ends in `Port`, `Repository` or `Gateway` must be a Protocol/ABC (or extend another such class).

Layout assumed: `src/<pkg>/{domain,application,ports,adapters,bootstrap,entrypoints}/`. Files elsewhere (for example `tests/`) are not layer-checked. Layers are found from the path, imports from the code (`import x`, `from x import y`, relative imports resolved).

Opt out for one class with `# archgate-ignore PY-004/ports-defined-inside-not-in-adapters <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- `class OrderRepository(Protocol): ...` in `ports/orders.py`
- `class PostgresOrderRepository: ...` in an adapter, matching the Protocol structurally

### Don't

- `class BaseRepo(ABC)` in `adapters/`
- A concrete `OrderRepository` class in `ports/`

## Consequences

The dependency direction is visible in the file tree. Rule `ports-defined-inside-not-in-adapters` in `PY-004-ports-live-inside.rules.ts`.
