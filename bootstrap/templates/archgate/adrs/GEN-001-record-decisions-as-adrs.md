---
id: GEN-001
title: Record architecture decisions as ADRs
domain: general
rules: false
---

# Record architecture decisions as ADRs

## Context

Decisions made in chat, reviews or AI sessions get lost, and new people (and Claude) repeat old debates.

## Decision

Decisions that constrain future code go in `.archgate/adrs/` as short ADRs. When a decision can be checked mechanically, add a companion `.rules.ts`; `archgate check` runs in `mise run lint` and CI.

## Do's and Don'ts

### Do

- One decision per ADR, with the context that made it the right call.
- Update or remove an ADR when the decision changes.

### Don't

- Don't write ADRs for things a formatter or linter already enforces.

## Consequences

Reviews can point to a decision instead of re-arguing it; Claude reads the relevant ADRs before changing code.
