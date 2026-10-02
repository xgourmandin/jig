---
id: TS-004
title: Ports are interfaces owned by the inside
domain: typescript
rules: true
files:
  [
    "**/*.ts",
    "**/*.tsx",
    "**/*.mts",
    "**/*.cts",
    "**/*.js",
    "**/*.jsx",
    "**/*.mjs",
    "**/*.cjs",
    "**/*.vue",
    "**/*.svelte",
    "**/*.astro",
  ]
---

# Ports are interfaces owned by the inside

## Context

The inside defines what it needs (ports); adapters implement them. An interface declared in an adapter inverts that: the core ends up depending on the adapter to name its own dependency.

## Decision

Ports are `interface` (preferred) or `abstract class` declarations in `src/ports/` (or the domain/application). Adapters implement them but never declare an `abstract class`, nor an `interface` whose name ends in `Port`, `Repository` or `Gateway` (other local interfaces, such as option types, are fine). In `ports/`, a concrete `class` whose name ends in `Port`, `Repository` or `Gateway` is a violation.

Layout assumed: `src/{domain,application,ports,adapters/<name>,bootstrap,main}/` plus the frontend directories `src/{components,pages,routes,views,features,hooks,composables,stores,ui}/` (the "ui" layer; the full layout, how a feature-folder frontend maps onto it, the scanned file types and the alias rules are described in TS-001). Any other file under `src/` is "other"; files outside `src/` and test files are not layer-checked.

Opt out for one declaration with `// archgate-ignore TS-004/ports-defined-inside-not-in-adapters <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- `export interface OrderRepository { save(order: Order): Promise<void> }` in `ports/orders.ts`
- `export class PostgresOrderRepository implements OrderRepository` in an adapter

### Don't

- `export abstract class BaseRepo` in `adapters/`
- A concrete `class OrderRepository` in `ports/`

## Consequences

The dependency direction is visible in the file tree. Rule `ports-defined-inside-not-in-adapters` in `TS-004-ports-live-inside.rules.ts`.
