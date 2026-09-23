# jig-python

Enable in repos that contain Python.

| Component | File | What it does |
|---|---|---|
| LSP | dependency `pyright-lsp@claude-plugins-official` | Official plugin, installed automatically: pyright definitions, references, diagnostics after each edit |
| Edit checks (PostToolUse) | `hooks/scripts/py-post-edit.sh` | `ruff format` + `ruff check --fix` on every edited `.py`/`.pyi` (repo config and excludes apply); remaining issues fed back to Claude; records the file for Stop |
| Checks (Stop) | `hooks/scripts/py-stop-check.sh` | For each project edited this session: `pyright` on the edited files, then the project's `pytest` suite; blocks once on failures (the re-check after Claude's fix only reports, never blocks twice) |
| Tool check (SessionStart) | `hooks/scripts/check-tools.sh` | Tells Claude which binaries are missing |
| Skill | `skills/python-conventions` | Jig conventions, loaded automatically for Python files |

**Which tools run.** Each tool comes from the project's `.venv/bin` first (the version the project pins), then PATH (mise). pytest runs as `uv run --frozen pytest` when the project has `uv.lock`. The project is the nearest directory with `pyproject.toml`, `setup.cfg` or `setup.py`, so monorepos work. ruff's cache goes to the plugin data dir and pytest runs with `-p no:cacheprovider`, so the repo stays clean.

Requires `ruff`, `pyright` (the npm package, which also ships `pyright-langserver` for the LSP), `jq` on PATH, and `uv` or a pytest in the project (all via the repo's `mise.toml`, written by `jig-init`).

**Repo lint task.** When the repo defines a mise `lint` task (and mise is installed), jig-core runs `mise run lint` on Stop, the same check as CI, and this plugin skips `pyright` on Stop. Without one, it calls the tool directly.
