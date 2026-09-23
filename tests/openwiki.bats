#!/usr/bin/env bats
# Run: bats tests/   (openwiki is stubbed)
WRAPPER="$BATS_TEST_DIRNAME/../plugins/jig-openwiki/scripts/openwiki-mcp.sh"

setup() {
  STUBS="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$STUBS"
  ln -sf "$(command -v bash)" "$STUBS/bash"
}

@test "mcp wrapper: fails with a clear message when openwiki is missing" {
  run env PATH="$STUBS" bash "$WRAPPER"
  [ "$status" -eq 1 ]
  [[ "$output" == *"openwiki is not on PATH"* ]]
}

@test "mcp wrapper: runs the host-driven server for Claude with telemetry off" {
  cat >"$STUBS/openwiki" <<'STUB'
#!/bin/bash
echo "args=$* telemetry_disabled=$OPENWIKI_TELEMETRY_DISABLED"
STUB
  chmod +x "$STUBS/openwiki"
  run env -u OPENWIKI_TELEMETRY_DISABLED PATH="$STUBS" bash "$WRAPPER"
  [ "$status" -eq 0 ]
  [ "$output" = "args=mcp --host claude telemetry_disabled=1" ]
}
