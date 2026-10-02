---
id: PY-001
title: The domain imports nothing outward
domain: python
rules: true
files: ["**/*.py"]
---

# The domain imports nothing outward

## Context
Hexagonal architecture keeps business rules free of frameworks and infrastructure so they can be tested without a database or web server and survive a framework swap.

## Decision
Modules in `src/<pkg>/domain/` import only the standard library, third-party value libraries (for example pydantic) and other domain modules. They never import web/ORM/HTTP/cloud/queue clients (the list is in the rule file: fastapi, flask, django, sqlalchemy, requests, httpx, boto3, redis, celery, ...) nor `<pkg>.application`, `.ports`, `.adapters`, `.bootstrap` or `.entrypoints`.

Layout assumed: `src/<pkg>/{domain,application,ports,adapters,bootstrap,entrypoints}/`. Files elsewhere (for example `tests/`) are not layer-checked. Layers are found from the path, imports from the code (`import x`, `from x import y`, relative imports resolved).

Opt out for one import with a comment `# archgate-ignore PY-001/domain-imports-nothing-outward <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- `from .money import Money` inside the domain
- Express what the domain needs from the outside as a port
### Don't
- `import sqlalchemy` or `from fastapi import HTTPException` in the domain
- `from shop.adapters.db import OrderRow` in the domain

## Consequences
Domain tests run with no infrastructure. Rule `domain-imports-nothing-outward` in `PY-001-domain-has-no-outward-imports.rules.ts`.
