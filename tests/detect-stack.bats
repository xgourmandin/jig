#!/usr/bin/env bats
# Run: bats tests/
DETECT="$BATS_TEST_DIRNAME/../bootstrap/detect-stack.sh"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"; mkdir -p "$REPO"; cd "$REPO" || return 1; git init -q
}
add() { mkdir -p "$(dirname "$1")"; touch "$1"; git add "$1"; }
stacks() { bash "$DETECT" "$REPO" | paste -sd, -; }

@test "empty repo: no stacks"          { run stacks; [ -z "$output" ]; }
@test "terraform"                      { add infra/main.tf; run stacks; [ "$output" = terraform ]; }
@test "opentofu .tofu files"           { add main.tofu; run stacks; [ "$output" = terraform ]; }
@test "python via pyproject"           { add svc/pyproject.toml; run stacks; [ "$output" = python ]; }
@test "typescript via package.json"    { add web/package.json; run stacks; [ "$output" = typescript ]; }
@test "go via go.mod"                  { add go.mod; run stacks; [ "$output" = go ]; }
@test "mixed repo lists every stack"   { add a.py; add main.tf; add go.mod; run stacks; [ "$output" = "python,go,terraform" ]; }
@test "ignores untracked files"        { touch main.tf; add a.py; run stacks; [ "$output" = python ]; }
@test "non-git dir falls back to find" { d="$BATS_TEST_TMPDIR/plain"; mkdir -p "$d"; touch "$d/main.tf"; cd "$d"; GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run bash "$DETECT" "$d"; [ "$output" = terraform ]; }
