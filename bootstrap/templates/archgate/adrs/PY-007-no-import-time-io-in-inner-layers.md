---
id: PY-007
title: No I/O at import time in domain, application and ports
domain: python
rules: true
files: ["**/*.py"]
---

# No I/O at import time in domain, application and ports

## Context
Importing a module must be free of side effects. A file read, network call or environment lookup at module level makes tests slow and order-dependent and hides configuration that belongs to the composition root.

## Decision
In `src/<pkg>/{domain,application,ports}/`, a statement at module level (column 0) does not call `open`, `print`, `input`, `os.getenv`/`os.environ`, `requests`/`httpx`, `subprocess`, `socket`, `logging.basicConfig`, `load_dotenv` or `Path(...).read_*/write_*`. Do it inside a function. Reading configuration happens in `bootstrap` and is passed in. Adapters and bootstrap are not checked.

Layout assumed: `src/<pkg>/{domain,application,ports,adapters,bootstrap,entrypoints}/`. Files elsewhere (for example `tests/`) are not layer-checked. Layers are found from the path, imports from the code (`import x`, `from x import y`, relative imports resolved).

Opt out with `# archgate-ignore PY-007/no-import-time-io <reason>` on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- Read the environment in `bootstrap/settings.py` and pass values to constructors
### Don't
- `DB_URL = os.environ["DB_URL"]` at the top of a domain module

## Consequences
Rule `no-import-time-io` in `PY-007-no-import-time-io-in-inner-layers.rules.ts`.
