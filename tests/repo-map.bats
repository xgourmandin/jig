#!/usr/bin/env bats
# Run: bats tests/   (codebase-memory-mcp is stubbed)
CORE="$BATS_TEST_DIRNAME/../plugins/jig-core"

setup() {
  REPO="$BATS_TEST_TMPDIR/my repo.x"
  mkdir -p "$REPO"
  cd "$REPO" || return 1
  git init -q
  STUBS="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$STUBS"
  for b in bash git sed awk timeout; do ln -sf "$(command -v "$b")" "$STUBS/$b"; done
  export CALLS="$BATS_TEST_TMPDIR/calls"
}

# Fake codebase-memory-mcp: records args + allowed root, prints $STUB_OUT.
stub_cbm() {
  cat >"$STUBS/codebase-memory-mcp" <<'EOF'
#!/bin/bash
echo "args=$* root=$CBM_ALLOWED_ROOT" >>"$CALLS"
printf '%s' "$STUB_OUT"
EOF
  chmod +x "$STUBS/codebase-memory-mcp"
}

status_hook() { PATH="$STUBS" bash "$CORE/hooks/scripts/repo-map-status.sh"; }

@test "status: silent when codebase-memory-mcp is not installed" {
  run status_hook
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "status: indexed repo gets a one-line summary" {
  stub_cbm
  export STUB_OUT=$'project: x\nnodes: 22\nedges: 27\nstatus: ready\nindexed_at: 2026-09-23T09:41:17Z\n'
  run status_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"22 nodes, indexed 2026-09-23T09:41:17Z"* ]]
  # Project name derived from the path like the tool does it.
  expected="$(sed -E 's/[^A-Za-z0-9]+/-/g; s/^-+//; s/-+$//' <<<"$REPO")"
  grep -q -- "--project $expected root=$REPO" "$CALLS"
}

@test "status: unindexed repo gets the index instruction" {
  stub_cbm
  export STUB_OUT='{"error":"project not found or not indexed"}'
  run status_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"call the repo-map MCP tool index_repository with repo_path \"$REPO\""* ]]
}

@test "mcp wrapper: fails with a clear message when the binary is missing" {
  run env PATH="$STUBS" bash "$CORE/scripts/repo-map-mcp.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not on PATH"* ]]
}

@test "mcp wrapper: runs the server with reads limited to the project" {
  stub_cbm
  run env PATH="$STUBS" CLAUDE_PROJECT_DIR="$REPO" bash "$CORE/scripts/repo-map-mcp.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$CALLS")" = "args= root=$REPO" ]
}

@test "mcp wrapper: falls back to the git root" {
  stub_cbm
  mkdir -p sub && cd sub
  run env -u CLAUDE_PROJECT_DIR PATH="$STUBS" bash "$CORE/scripts/repo-map-mcp.sh"
  [ "$(cat "$CALLS")" = "args= root=$REPO" ]
}
