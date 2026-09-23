---
name: python-conventions
description: Jig conventions for writing Python code (tooling, typing, layout, tests, errors). Loaded automatically when working on .py files.
paths:
  - "**/*.py"
  - "**/*.pyi"
  - "**/pyproject.toml"
user-invocable: false
---

# Python conventions (Jig)

Company-wide defaults. A repo's own `.claude/rules/` files or ADRs in `.archgate/adrs/` override them.

**Tooling.** uv manages the environment: `uv add` / `uv add --dev` for dependencies (never hand-edit versions in `uv.lock`, never `pip install` into the venv), `uv run <cmd>` to run anything. ruff formats and lints, pyright type-checks, pytest tests. Their config lives in `pyproject.toml`. The hooks run ruff after every edit and pyright + pytest when you stop, so fix what they report instead of silencing it.

**Typing.** Type every public function signature and return value. Prefer built-in generics (`list[str]`, `X | None`). Avoid `Any` and `cast`. `# type: ignore[code]` or `# noqa: CODE` only with a reason in a comment, and only if the user agrees.

**Layout.** `src/<package>/` layout with tests in `tests/` mirroring the package. No logic in `__init__.py` beyond re-exports. Module-level code has no side effects (no I/O at import time).

**Errors and logging.** Raise specific exceptions, never bare `except:` or `except Exception: pass`. Use `logging` (module-level `logger = logging.getLogger(__name__)`), not `print`, outside CLIs.

**Tests.** pytest, plain `assert`, fixtures over setup methods. A bug fix starts with a failing test. Don't weaken or skip a failing test to make the Stop hook pass.

**Security.** No secrets in code or tests. Use `subprocess` with argument lists (no `shell=True` with user input). Parameterise SQL.

**Finding things.** Use the LSP (go to definition, find references, hover types) before grepping.
