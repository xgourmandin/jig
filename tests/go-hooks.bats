#!/usr/bin/env bats
# Run: bats tests/   (needs go, goimports and golangci-lint from `mise install`)
SCRIPTS="$BATS_TEST_DIRNAME/../plugins/jig-go/hooks/scripts"
FIXTURE="$BATS_TEST_DIRNAME/fixtures/go-sample"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cp -r "$FIXTURE/." "$REPO/"
  cd "$REPO" || return 1
  git init -q -b main
  git add -A && git -c user.name=t -c user.email=t@t commit -qm fixture
  export CLAUDE_PLUGIN_DATA="$BATS_TEST_TMPDIR/data"
  STATE="$CLAUDE_PLUGIN_DATA/sessions/s1.files"
}

edit()  { jq -nc --arg f "$1" '{session_id:"s1",tool_name:"Edit",tool_input:{file_path:$f}}' | bash "$SCRIPTS/go-post-edit.sh"; }
stop()  { jq -nc --argjson a "${1:-false}" '{session_id:"s1",hook_event_name:"Stop",stop_hook_active:$a}' | bash "$SCRIPTS/go-stop-check.sh"; }
CALC="calc/calc.go"

# The repo defines a mise lint task (jig-core runs it); a fake mise is enough here.
with_lint_task() {
  printf '\n[tasks.lint]\nrun = "true"\n' >>mise.toml
  MISEBIN="$BATS_TEST_TMPDIR/misebin"; mkdir -p "$MISEBIN"
  printf '#!/bin/sh\nexit 0\n' >"$MISEBIN/mise"; chmod +x "$MISEBIN/mise"
  export PATH="$MISEBIN:$PATH"
}

# Directory of fake binaries, to control what is "installed". Real ones can be
# passed as "=name" (symlinked from PATH).
stub_bin() {
  STUBS="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$STUBS"
  for b in "$@"; do
    if [[ "$b" == =* ]]; then ln -sf "$(command -v "${b#=}")" "$STUBS/${b#=}"
    else printf '#!/bin/sh\nexit 0\n' >"$STUBS/$b"; chmod +x "$STUBS/$b"; fi
  done
  for b in bash jq git grep sed mkdir dirname cat sort head tail rm basename; do ln -sf "$(command -v "$b")" "$STUBS/$b"; done
}

# --- lib -----------------------------------------------------------------------
@test "root: nearest go.mod (nested module), not above the git root" {
  mkdir -p svc/api && printf 'module example.com/svc\n' >svc/go.mod && touch svc/api/x.go
  run bash -c "source '$SCRIPTS/lib.sh'; jig_go_root '$REPO/svc/api/x.go'"
  [ "$output" = "$REPO/svc" ]
  run bash -c "source '$SCRIPTS/lib.sh'; jig_go_root '$REPO/$CALC'"
  [ "$output" = "$REPO" ]
}
@test "root: none when there is no go.mod up to the git root" {
  rm go.mod; printf 'module example.com/outside\n' >"$BATS_TEST_TMPDIR/go.mod"
  run bash -c "source '$SCRIPTS/lib.sh'; jig_go_root '$REPO/$CALC'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
@test "pkg: package pattern relative to the module root" {
  run bash -c "source '$SCRIPTS/lib.sh'; jig_go_pkg '$REPO' '$REPO/$CALC'; jig_go_pkg '$REPO' '$REPO/main.go'"
  [ "$output" = $'./calc\n.' ]
}
@test "formatter: goimports, else gofmt" {
  stub_bin goimports gofmt
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_go_formatter"
  [ "$output" = "$STUBS/goimports" ]
  rm "$STUBS/goimports"
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_go_formatter"
  [ "$output" = "$STUBS/gofmt" ]
}

# --- PostToolUse: go-post-edit.sh ----------------------------------------------
@test "post-edit: ignores non-Go files" {
  echo x >README.md
  run edit "$REPO/README.md"
  [ "$status" -eq 0 ]
  [ ! -e "$STATE" ]
}
@test "post-edit: clean file passes, is untouched and recorded once" {
  run edit "$REPO/$CALC"
  [ "$status" -eq 0 ]
  [ -z "$(git status --porcelain)" ]
  [ "$(cat "$STATE")" = "$REPO/$CALC" ]
  run edit "$REPO/$CALC"
  [ "$(wc -l <"$STATE")" -eq 1 ]
}
@test "post-edit: formats the file and adds the missing import" {
  printf 'package calc\nfunc Upper( s string ) string {\nreturn strings.ToUpper(s)}\n' >calc/extra.go
  run edit "$REPO/calc/extra.go"
  [ "$status" -eq 0 ]
  grep -q '^import "strings"$' calc/extra.go
  grep -q '^func Upper(s string) string {$' calc/extra.go
  grep -q $'^\treturn strings.ToUpper(s)$' calc/extra.go
}
@test "post-edit: falls back to gofmt without goimports" {
  stub_bin =gofmt
  printf 'package calc\nfunc Two( ) int {\nreturn 2}\n' >calc/extra.go
  run env PATH="$STUBS" bash -c "jq -nc --arg f '$REPO/calc/extra.go' '{session_id:\"s1\",tool_input:{file_path:\$f}}' | bash '$SCRIPTS/go-post-edit.sh'"
  [ "$status" -eq 0 ]
  grep -q '^func Two() int {$' calc/extra.go
}
@test "post-edit: syntax error blocks and leaves the file as is" {
  printf 'package calc\n\nfunc Bad( {\n' >calc/bad.go
  run edit "$REPO/calc/bad.go"
  [ "$status" -eq 2 ]
  [[ "$output" == *"goimports failed (likely a syntax error)"*"bad.go:3:"* ]]
  [ "$(cat calc/bad.go)" = $'package calc\n\nfunc Bad( {' ]
}
@test "post-edit: no formatter installed is a no-op (still recorded)" {
  stub_bin
  run env PATH="$STUBS" bash -c "jq -nc --arg f '$REPO/$CALC' '{session_id:\"s1\",tool_input:{file_path:\$f}}' | bash '$SCRIPTS/go-post-edit.sh'"
  [ "$status" -eq 0 ]
  [ -s "$STATE" ]
}

# --- Stop: go-stop-check.sh ----------------------------------------------------
@test "stop: nothing edited -> allow silently" {
  run stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
@test "stop: clean edits pass, clear the session list and leave the repo clean" {
  edit "$REPO/$CALC"
  run stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$STATE" ]
  [ -z "$(git status --porcelain --ignored)" ]
}
@test "stop: lint issue blocks once with golangci-lint output" {
  printf 'package calc\n\nimport "os"\n\n// Rm removes x.\nfunc Rm() { os.Remove("x") }\n' >calc/rm.go
  edit "$REPO/calc/rm.go"
  run stop
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(golangci-lint, exit 1)"*"calc/rm.go:6:"*"(errcheck)"* ]]
  [ -s "$STATE" ]
  run stop true
  [ "$(jq -r '.decision // empty' <<<"$output")" = "" ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"checks still fail after Claude's fix"*"(errcheck)"* ]]
  [ -s "$STATE" ]
}
@test "stop: re-check after a block passes silently and clears the list" {
  edit "$REPO/calc/calc.go"
  run stop true
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$STATE" ]
}
@test "stop: lint task present -> golangci-lint skipped, go test still runs" {
  with_lint_task
  printf 'package calc\n\nimport "os"\n\n// Rm removes x.\nfunc Rm() { os.Remove("x") }\n' >calc/rm.go
  edit "$REPO/calc/rm.go"
  run stop
  [ -z "$output" ]
}
@test "stop: failing test blocks with go test output" {
  sed -i 's/return a + b/return a - b/' "$CALC"
  edit "$REPO/$CALC"
  run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(go test, exit 1)"*"TestAdd"* ]]
}
@test "stop: compile error blocks" {
  printf '\n// Bad does not compile.\nfunc Bad() int { return "s" }\n' >>"$CALC"
  edit "$REPO/$CALC"
  run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(typecheck)"*"(go test, exit 1)"*"build failed"* ]]
}
@test "stop: checks only the edited packages" {
  mkdir other && printf 'package other\n\nimport "testing"\n\nfunc TestFail(t *testing.T) { t.Fatal("boom") }\n' >other/other_test.go
  edit "$REPO/$CALC"
  run stop
  [ -z "$output" ]
}
@test "stop: nested module is checked from its own root" {
  mkdir -p svc/api && printf 'module example.com/svc\n\ngo 1.25\n' >svc/go.mod
  printf 'package api\n\nimport "testing"\n\nfunc TestFail(t *testing.T) { t.Fatal("boom") }\n' >svc/api/api_test.go
  edit "$REPO/svc/api/api_test.go"
  run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"## $REPO/svc (go test, exit 1)"*"boom"* ]]
  [[ "$(jq -r .reason <<<"$output")" != *"## $REPO ("* ]]
}
@test "stop: never changes go.mod or go.sum" {
  printf 'package calc\n\nimport "github.com/example/missing"\n\n// M uses a module not in go.mod.\nfunc M() { missing.Do() }\n' >calc/dep.go
  edit "$REPO/calc/dep.go"
  run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"github.com/example/missing: import lookup disabled by -mod=readonly"* ]]
  [ -z "$(git status --porcelain go.mod)" ] && [ ! -e go.sum ]
}
@test "stop: unloadable golangci-lint config (v1) only warns" {
  printf 'linters:\n  enable:\n    - errcheck\n' >.golangci.yml
  edit "$REPO/$CALC"
  run stop
  [ "$(jq -r .decision <<<"$output")" = null ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"could not load the config"* ]]
  [ ! -e "$STATE" ]
}
@test "stop: without golangci-lint, go vet runs and a warning is shown" {
  stub_bin =go
  printf 'package calc\n\nimport "fmt"\n\n// P prints.\nfunc P() { fmt.Printf("%%d\\n", "s") }\n' >calc/p.go
  edit "$REPO/calc/p.go"
  run env PATH="$STUBS" bash -c "jq -nc '{session_id:\"s1\"}' | bash '$SCRIPTS/go-stop-check.sh'"
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(go vet)"*"Printf format %d"*"golangci-lint not found"* ]]
}
@test "stop: missing tools only warn" {
  stub_bin
  edit "$REPO/$CALC"
  run env PATH="$STUBS" bash -c "jq -nc '{session_id:\"s1\"}' | bash '$SCRIPTS/go-stop-check.sh'"
  [ "$status" -eq 0 ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"go not found"* ]]
}
@test "stop: files outside any module are skipped" {
  rm go.mod
  edit "$REPO/$CALC"
  run stop
  [ -z "$output" ]
}

# --- SessionStart: check-tools.sh ----------------------------------------------
@test "check-tools: silent when tools are installed" {
  run bash "$SCRIPTS/check-tools.sh"
  [ -z "$output" ]
}
@test "check-tools: names missing tools" {
  stub_bin go
  run env PATH="$STUBS" bash "$SCRIPTS/check-tools.sh"
  [[ "$output" == *"missing tools: gopls, goimports, golangci-lint"* ]]
}
@test "check-tools: silent in repos without Go" {
  git rm -rq . && rm -rf calc; stub_bin
  run env PATH="$STUBS" bash "$SCRIPTS/check-tools.sh"
  [ -z "$output" ]
}
