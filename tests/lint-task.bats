#!/usr/bin/env bats
# Run: bats tests/
# jig-core: record-edit.sh (PostToolUse), lint-task.sh (Stop) and the shared
# jig_lint_task helper.
PLUGINS="$BATS_TEST_DIRNAME/../plugins"
SCRIPTS="$PLUGINS/jig-core/hooks/scripts"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/src" "$REPO/.ai/work/main"
  cd "$REPO" || return 1
  git init -q -b main
  echo x >src/app.py
  echo x >.ai/work/main/progress.md
  export CLAUDE_PLUGIN_DATA="$BATS_TEST_TMPDIR/data"
  STATE="$CLAUDE_PLUGIN_DATA/sessions/s1.files"
  # Fake mise: logs its args, prints $MISE_OUT, exits $MISE_RC.
  BIN="$BATS_TEST_TMPDIR/bin"; mkdir -p "$BIN"
  export MISE_LOG="$BATS_TEST_TMPDIR/mise.log"
  printf '#!/bin/sh\necho "$* auto=$MISE_TASK_RUN_AUTO_INSTALL" >>"$MISE_LOG"\nprintf "%%s\\n" "${MISE_OUT:-}"\nexit "${MISE_RC:-0}"\n' >"$BIN/mise"
  chmod +x "$BIN/mise"
  export PATH="$BIN:$PATH"
}

edit() { jq -nc --arg f "$1" '{session_id:"s1",tool_name:"Edit",tool_input:{file_path:$f}}' | bash "$SCRIPTS/record-edit.sh"; }
stop() { jq -nc --argjson a "${1:-false}" '{session_id:"s1",hook_event_name:"Stop",stop_hook_active:$a}' | bash "$SCRIPTS/lint-task.sh"; }
has_task() { bash -c "source '$SCRIPTS/lib.sh'; jig_lint_task '$REPO'"; }
with_task() { printf '[tasks.lint]\nrun = "echo lint"\n' >mise.toml; }

# --- jig_lint_task ---------------------------------------------------------------
@test "lint task: [tasks.lint] table" {
  with_task
  run has_task; [ "$status" -eq 0 ]
}
@test "lint task: lint key under [tasks], quoted or not" {
  printf '[tools]\njq = "1"\n\n[tasks]\nlint = "echo"\n' >mise.toml
  run has_task; [ "$status" -eq 0 ]
  printf '[tasks]\n"lint" = { run = "echo" }\n' >.mise.toml; rm mise.toml
  run has_task; [ "$status" -eq 0 ]
}
@test "lint task: file task in mise-tasks/" {
  mkdir -p mise-tasks && printf '#!/bin/sh\n' >mise-tasks/lint
  run has_task; [ "$status" -eq 0 ]
}
@test "lint task: other tasks or a lint key outside [tasks] don't count" {
  printf '[tasks.lint-fix]\nrun = "x"\n\n[tasks.test]\nlint = "x"\n\n[env]\nlint = "x"\n' >mise.toml
  run has_task; [ "$status" -ne 0 ]
}
@test "lint task: none without a mise config" {
  run has_task; [ "$status" -ne 0 ]
}
@test "lint task: none when mise is not installed" {
  with_task
  NOMISE="$BATS_TEST_TMPDIR/nomise"; mkdir -p "$NOMISE"
  for b in bash awk; do ln -sf "$(command -v "$b")" "$NOMISE/$b"; done
  run env PATH="$NOMISE" bash -c "source '$SCRIPTS/lib.sh'; jig_lint_task '$REPO'"
  [ "$status" -ne 0 ]
}
@test "lint task: helper is identical in every plugin's lib.sh" {
  fn() { sed -n '/^jig_lint_task() {$/,/^}$/p' "$1"; }
  want="$(fn "$SCRIPTS/lib.sh")"
  [ -n "$want" ]
  for p in jig-terraform jig-python jig-typescript jig-go; do
    [ "$(fn "$PLUGINS/$p/hooks/scripts/lib.sh")" = "$want" ]
  done
}

# --- PostToolUse: record-edit.sh ---------------------------------------------------
@test "record: repo file recorded once" {
  edit "$REPO/src/app.py"; edit "$REPO/src/app.py"
  [ "$(cat "$STATE")" = "$REPO/src/app.py" ]
}
@test "record: work state under .ai/ ignored" {
  edit "$REPO/.ai/work/main/progress.md"
  [ ! -e "$STATE" ]
}
@test "record: files outside a git repo ignored" {
  mkdir -p "$BATS_TEST_TMPDIR/elsewhere" && echo x >"$BATS_TEST_TMPDIR/elsewhere/f"
  edit "$BATS_TEST_TMPDIR/elsewhere/f"
  [ ! -e "$STATE" ]
}

# --- Stop: lint-task.sh -------------------------------------------------------------
@test "stop: nothing edited -> no lint run" {
  with_task
  run stop
  [ -z "$output" ]; [ ! -e "$MISE_LOG" ]
}
@test "stop: no lint task -> no-op, list cleared" {
  edit "$REPO/src/app.py"
  run stop
  [ -z "$output" ]; [ ! -e "$MISE_LOG" ]; [ ! -e "$STATE" ]
}
@test "stop: lint passes -> silent, list cleared, no tool auto-install" {
  with_task; edit "$REPO/src/app.py"
  run stop
  [ "$status" -eq 0 ]; [ -z "$output" ]; [ ! -e "$STATE" ]
  [ "$(cat "$MISE_LOG")" = "run lint auto=false" ]
}
@test "stop: lint fails -> blocks once with the output" {
  with_task; edit "$REPO/src/app.py"
  MISE_RC=1 MISE_OUT="src/app.py:1 E999 boom" run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"mise run lint"*"predates this session"*"E999 boom"* ]]
  [ -s "$STATE" ]
}
@test "stop: re-check after a block reports but never blocks twice" {
  with_task; edit "$REPO/src/app.py"
  MISE_RC=1 MISE_OUT="still broken" run stop true
  [ "$(jq -r '.decision // empty' <<<"$output")" = "" ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"still fails after Claude's fix"*"still broken"* ]]
  [ -s "$STATE" ]
}
@test "stop: re-check after a block passes silently and clears the list" {
  with_task; edit "$REPO/src/app.py"
  run stop true
  [ -z "$output" ]; [ ! -e "$STATE" ]
}
@test "stop: untrusted mise config warns instead of blocking" {
  with_task; edit "$REPO/src/app.py"
  MISE_RC=1 MISE_OUT="mise ERROR Config files in $REPO/mise.toml are not trusted." run stop
  [ "$(jq -r '.decision // empty' <<<"$output")" = "" ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"mise trust"* ]]
}
