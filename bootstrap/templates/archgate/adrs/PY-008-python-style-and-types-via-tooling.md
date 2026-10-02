---
id: PY-008
title: Types and style are enforced by pyright and ruff
domain: python
rules: false
files: ["**/*.py"]
---

# Types and style are enforced by pyright and ruff

## Context
Type hints, formatting, import order, unused code and many bug patterns are mechanical and pyright and ruff already check them. Re-implementing them as Archgate rules would duplicate maintained tools.

## Decision
Every Python project configures, in `pyproject.toml`:
- pyright `typeCheckingMode = "strict"` (for new code; legacy code may start at `"standard"` and ratchet up), run by `mise run lint`.
- ruff with at least the rule sets `E`, `F`, `I`, `B`, `UP`, `S` and `format`.
- Optionally [import-linter](https://import-linter.readthedocs.io) contracts if the layer rules of PY-001 to PY-004 need more than the path-based check (for example a non-`src/` layout).

The jig-python plugin already runs ruff on edit and pyright on Stop; this ADR makes the configuration part of the repo. There is no `.rules.ts` for it, on purpose.

## Do's and Don'ts
### Do
- Annotate every public function; fix pyright errors rather than adding `# type: ignore`
### Don't
- Disable strict mode globally to silence errors

## Consequences
CI and the agent run the same checks through `mise run lint`.
