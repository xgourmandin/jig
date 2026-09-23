#!/usr/bin/env bats
# Run: bats tests/   (needs ruff, pyright and pytest from `mise install`)
SCRIPTS="$BATS_TEST_DIRNAME/../plugins/jig-python/hooks/scripts"
FIXTURE="$BATS_TEST_DIRNAME/fixtures/py-sample"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cp -r "$FIXTURE/." "$REPO/"
  rm -rf "$REPO/.ruff_cache" "$REPO/.pytest_cache"
  cd "$REPO" || return 1
  git init -q -b main
  export CLAUDE_PLUGIN_DATA="$BATS_TEST_TMPDIR/data"
  STATE="$CLAUDE_PLUGIN_DATA/sessions/s1.files"
}

edit()  { jq -nc --arg f "$1" '{session_id:"s1",tool_name:"Edit",tool_input:{file_path:$f}}' | bash "$SCRIPTS/py-post-edit.sh"; }
stop()  { jq -nc --argjson a "${1:-false}" '{session_id:"s1",hook_event_name:"Stop",stop_hook_active:$a}' | bash "$SCRIPTS/py-stop-check.sh"; }
CALC="src/pysample/calc.py"

# The repo defines a mise lint task (jig-core runs it); a fake mise is enough here.
with_lint_task() {
  printf '\n[tasks.lint]\nrun = "true"\n' >>mise.toml
  MISEBIN="$BATS_TEST_TMPDIR/misebin"; mkdir -p "$MISEBIN"
  printf '#!/bin/sh\nexit 0\n' >"$MISEBIN/mise"; chmod +x "$MISEBIN/mise"
  export PATH="$MISEBIN:$PATH"
}

# Directory of fake binaries, to control what is "installed".
stub_bin() {
  STUBS="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$STUBS"
  for b in "$@"; do printf '#!/bin/sh\nexit 0\n' >"$STUBS/$b"; chmod +x "$STUBS/$b"; done
  for b in bash jq git grep mkdir dirname cat sort head tail rm basename; do ln -sf "$(command -v "$b")" "$STUBS/$b"; done
}

# --- lib -----------------------------------------------------------------------
@test "root: nearest pyproject.toml, not above the git root" {
  mkdir -p svc/app && touch svc/pyproject.toml svc/app/x.py
  run bash -c "source '$SCRIPTS/lib.sh'; jig_py_root '$REPO/svc/app/x.py'"
  [ "$output" = "$REPO/svc" ]
  run bash -c "source '$SCRIPTS/lib.sh'; jig_py_root '$REPO/$CALC'"
  [ "$output" = "$REPO" ]
}
@test "root: git root when there is no project file" {
  rm pyproject.toml; mkdir -p a && touch a/x.py
  run bash -c "source '$SCRIPTS/lib.sh'; jig_py_root '$REPO/a/x.py'"
  [ "$output" = "$REPO" ]
}
@test "tool: project .venv wins over PATH" {
  mkdir -p .venv/bin && printf '#!/bin/sh\n' >.venv/bin/ruff && chmod +x .venv/bin/ruff
  run bash -c "source '$SCRIPTS/lib.sh'; jig_py_tool '$REPO' ruff"
  [ "$output" = "$REPO/.venv/bin/ruff" ]
}
@test "pytest: uv run when the project has uv.lock and uv is installed" {
  stub_bin uv pytest; touch uv.lock
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_py_pytest '$REPO'"
  [ "$output" = $'uv\nrun\n--frozen\npytest' ]
}
@test "pytest: PATH pytest without uv.lock" {
  stub_bin uv pytest
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_py_pytest '$REPO'"
  [ "$output" = "$STUBS/pytest" ]
}

# --- PostToolUse: py-post-edit.sh ----------------------------------------------
@test "post-edit: ignores non-Python files" {
  echo x >README.md
  run edit "$REPO/README.md"
  [ "$status" -eq 0 ]
  [ ! -e "$STATE" ]
}
@test "post-edit: clean file passes and is recorded once" {
  run edit "$REPO/$CALC"
  [ "$status" -eq 0 ]
  [ "$(cat "$STATE")" = "$REPO/$CALC" ]
  run edit "$REPO/$CALC"
  [ "$(wc -l <"$STATE")" -eq 1 ]
}
@test "post-edit: formats the file and fixes import order" {
  printf 'import sys\nimport os\ndef f( x ):\n    return os.sep+sys.platform+x\n' >src/pysample/extra.py
  run edit "$REPO/src/pysample/extra.py"
  [ "$status" -eq 0 ]
  grep -q '^def f(x):' src/pysample/extra.py
  [ "$(head -1 src/pysample/extra.py)" = "import os" ]
}
@test "post-edit: syntax error blocks with a format message" {
  printf 'def f(:\n' >src/pysample/bad.py
  run edit "$REPO/src/pysample/bad.py"
  [ "$status" -eq 2 ]
  [[ "$output" == *"ruff format failed"* ]]
}
@test "post-edit: unfixable lint issue blocks with ruff output" {
  printf 'def f() -> int:\n    return undefined_name\n' >src/pysample/lint.py
  run edit "$REPO/src/pysample/lint.py"
  [ "$status" -eq 2 ]
  [[ "$output" == *"F821"* ]]
}
@test "post-edit: respects the repo's ruff excludes" {
  printf '[tool.ruff]\nextend-exclude = ["legacy"]\n' >>pyproject.toml
  sed -i '0,/^\[tool.ruff\]$/{/^\[tool.ruff\]$/d}' pyproject.toml
  mkdir legacy && printf 'x = undefined_name\n' >legacy/old.py
  run edit "$REPO/legacy/old.py"
  [ "$status" -eq 0 ]
}
@test "post-edit: no ruff installed is a no-op (still recorded)" {
  stub_bin
  run env PATH="$STUBS" bash -c "jq -nc --arg f '$REPO/$CALC' '{session_id:\"s1\",tool_input:{file_path:\$f}}' | bash '$SCRIPTS/py-post-edit.sh'"
  [ "$status" -eq 0 ]
  [ -s "$STATE" ]
}

# --- Stop: py-stop-check.sh ----------------------------------------------------
@test "stop: nothing edited -> allow silently" {
  run stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
@test "stop: clean edits pass and clear the session list" {
  edit "$REPO/$CALC"
  run stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$STATE" ]
}
@test "stop: type error blocks once with pyright output" {
  printf '\n\ndef twice(x: int) -> str:\n    return x * 2\n' >>"$CALC"
  edit "$REPO/$CALC"
  run stop
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(pyright)"*"calc.py:"* ]]
  [ -s "$STATE" ]
  run stop true
  [ "$(jq -r '.decision // empty' <<<"$output")" = "" ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"checks still fail after Claude's fix"*"(pyright)"* ]]
  [ -s "$STATE" ]
}
@test "stop: re-check after a block passes silently and clears the list" {
  edit "$REPO/$CALC"
  run stop true
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$STATE" ]
}
@test "stop: lint task present -> pyright skipped, tests still run" {
  with_lint_task
  printf '\n\ndef twice(x: int) -> str:\n    return x * 2\n' >>"$CALC"
  edit "$REPO/$CALC"
  run stop
  [ -z "$output" ]
  sed -i 's/return a + b/return a - b/' "$CALC"
  edit "$REPO/$CALC"
  run stop
  [[ "$(jq -r .reason <<<"$output")" == *"(pytest, exit 1)"* ]]
  [[ "$(jq -r .reason <<<"$output")" != *"(pyright)"* ]]
}
@test "stop: failing test blocks with pytest output" {
  sed -i 's/return a + b/return a - b/' "$CALC"
  edit "$REPO/$CALC"
  run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(pytest, exit 1)"*"test_add"* ]]
}
@test "stop: no tests collected is fine" {
  rm -r tests && sed -i '/^testpaths/d' pyproject.toml
  edit "$REPO/$CALC"
  run stop
  [ -z "$output" ]
}
@test "stop: leaves no cache files in the repo" {
  edit "$REPO/$CALC"
  stop
  [ ! -d .pytest_cache ] && [ ! -d .ruff_cache ]
  [ -z "$(find . -name __pycache__)" ]
}
@test "stop: missing tools only warn" {
  stub_bin
  edit "$REPO/$CALC"
  run env PATH="$STUBS" bash -c "jq -nc '{session_id:\"s1\"}' | bash '$SCRIPTS/py-stop-check.sh'"
  [ "$status" -eq 0 ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"pyright not found"*"pytest not found"* ]]
}

# --- SessionStart: check-tools.sh ----------------------------------------------
@test "check-tools: silent when tools are installed" {
  git add -A
  run bash "$SCRIPTS/check-tools.sh"
  [ -z "$output" ]
}
@test "check-tools: names missing tools" {
  git add -A; stub_bin ruff
  run env PATH="$STUBS" bash "$SCRIPTS/check-tools.sh"
  [[ "$output" == *"missing tools: pyright, pyright-langserver"* ]]
}
@test "check-tools: silent in repos without Python" {
  rm -rf src tests; stub_bin
  run env PATH="$STUBS" bash "$SCRIPTS/check-tools.sh"
  [ -z "$output" ]
}
