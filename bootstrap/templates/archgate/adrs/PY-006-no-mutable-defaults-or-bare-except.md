---
id: PY-006
title: No mutable default arguments or bare except
domain: python
rules: true
files: ["**/*.py"]
---

# No mutable default arguments or bare except

## Context
A mutable default is shared by every call, and `except:` also catches `KeyboardInterrupt` and `SystemExit`. Both cause bugs that are hard to trace. Ruff has B006 and E722; this rule keeps them enforced even when a repo's ruff config does not select them.

## Decision
No default values that are list/dict/set literals or calls to `list()`, `dict()`, `set()`, `defaultdict()` and similar in function signatures. No bare `except:`. Opt out with `# archgate-ignore PY-006/<rule> <reason>` (`<rule>` is `no-mutable-default-args` or `no-bare-except`) on the line before it. The reason is required, without one the violation stays.

## Do's and Don'ts
### Do
- `def add(item, items: list[str] | None = None): items = items or []`
- `except Exception as exc:` or a specific exception
### Don't
- `def add(item, items=[])`
- `except:`

## Consequences
Rules `no-mutable-default-args` and `no-bare-except` in `PY-006-no-mutable-defaults-or-bare-except.rules.ts`.
