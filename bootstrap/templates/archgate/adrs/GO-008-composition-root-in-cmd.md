---
id: GO-008
title: The composition root lives in cmd/
domain: go
rules: true
files: ["**/*.go"]
---

# The composition root lives in cmd/

## Context

Somewhere the concrete adapters must be created and handed to the use cases. If that happens in random packages, the dependency direction (GO-001..GO-003) erodes through the back door.

## Decision

`func main` and the construction of adapters happen only under `cmd/<binary>/`. Outside `cmd/`, non-test files:

- are not `package main` with a `func main` (binaries go to `cmd/<name>/main.go`);
- do not import `internal/adapters/...`, unless they are inside `internal/adapters` themselves. Domain, app and ports are covered by GO-001/GO-002; this rule covers everything else (a root `main.go`, `internal/server`, `internal/wiring`, ...).

Opt out for one site with `// archgate-ignore GO-008/composition-root-in-cmd <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- `cmd/api/main.go` builds `postgres.NewOrderRepo(db)` and passes it to `app.NewPlaceOrder(repo)`.

### Don't

- A `main.go` at the repository root, or `internal/server` importing `internal/adapters/postgres`.

## Consequences

One place to read to see how the service is assembled. Rule `composition-root-in-cmd` in `GO-008-composition-root-in-cmd.rules.ts`.
