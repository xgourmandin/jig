---
id: PY-003
title: Adapters depend inward and never on each other
domain: python
rules: true
files: ["**/*.py"]
---

# Adapters depend inward and never on each other

## Context

Adapters translate between the outside world and the ports. When one adapter calls another, a technology choice leaks sideways and swapping either becomes a rewrite.

## Decision

Adapters (`src/<pkg>/adapters/<name>/` or `adapters/<name>.py`) may import the domain, ports, application, frameworks and their own modules. They do not import another adapter, `<pkg>.bootstrap` or `<pkg>.entrypoints`. When two adapters need the same thing, put it in the domain or a port.

Layout assumed: `src/<pkg>/{domain,application,ports,adapters,bootstrap,entrypoints}/`. Files elsewhere (for example `tests/`) are not layer-checked. Layers are found from the path, imports from the code (`import x`, `from x import y`, relative imports resolved).

Opt out for one import with `# archgate-ignore PY-003/adapters-do-not-import-each-other <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts

### Do

- `from shop.ports.mailer import Mailer` in an adapter that needs a mailer

### Don't

- `from shop.adapters.smtp import SmtpMailer` inside `adapters/postgres/`

## Consequences

Adapters can be replaced one at a time. Rule `adapters-do-not-import-each-other` in `PY-003-adapters-depend-inward.rules.ts`.
