---
id: PY-005
title: No wildcard imports
domain: python
rules: true
files: ["**/*.py"]
---

# No wildcard imports

## Context

`from x import *` hides where names come from, defeats dependency checks like PY-001 to PY-003 and breaks type checking when `__all__` drifts. Ruff has F403 for the same thing; this rule makes it independent of the repo's ruff selection.

## Decision

No `from x import *` in any Python file. Opt out with `# archgate-ignore PY-005/no-wildcard-imports <reason>` on the line before it. The reason is required, without one the violation stays. A deliberate re-export in `__init__.py` is the typical case.

## Do's and Don'ts

### Do

- `from .money import Money, Currency`

### Don't

- `from .money import *`

## Consequences

Imports stay explicit and checkable. Rule `no-wildcard-imports` in `PY-005-no-wildcard-imports.rules.ts`.
