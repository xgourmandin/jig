#!/usr/bin/env bats
# Run: bats tests/
INSTALL="$BATS_TEST_DIRNAME/../bootstrap/install.sh"

# Fake harness repo whose jig-init records its cwd, args and marketplace URL.
setup() {
  FAKE="$BATS_TEST_TMPDIR/fake-harness"
  mkdir -p "$FAKE/bootstrap"
  cat >"$FAKE/bootstrap/jig-init" <<'STUB'
#!/usr/bin/env bash
{ pwd; echo "url=${JIG_MARKETPLACE_URL:-}"; printf 'arg=%s\n' "$@"; } >"$OUT"
STUB
  chmod +x "$FAKE/bootstrap/jig-init"
  git -C "$FAKE" init -q -b main
  git -C "$FAKE" add -A
  git -C "$FAKE" -c user.name=t -c user.email=t@t commit -q -m init
  git -C "$FAKE" tag v1
  TARGET="$BATS_TEST_TMPDIR/target"
  mkdir -p "$TARGET"
  cd "$TARGET" || return 1
  export OUT="$BATS_TEST_TMPDIR/out"
  export JIG_HARNESS_URL="file://$FAKE"
  unset JIG_MARKETPLACE_URL JIG_HARNESS_REF
}

@test "piped to sh: runs jig-init in the caller's cwd with args" {
  run sh -s -- --tofu --openwiki <"$INSTALL"
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p "$OUT")" = "$TARGET" ]
  grep -qx 'arg=--tofu' "$OUT"
  grep -qx 'arg=--openwiki' "$OUT"
}

@test "marketplace URL defaults to the clone URL" {
  run sh "$INSTALL"
  [ "$status" -eq 0 ]
  grep -qx "url=file://$FAKE" "$OUT"
}

@test "explicit JIG_MARKETPLACE_URL wins" {
  JIG_MARKETPLACE_URL=https://example.com/m.git run sh "$INSTALL"
  [ "$status" -eq 0 ]
  grep -qx 'url=https://example.com/m.git' "$OUT"
}

@test "the clone URL it passes reaches jig-init's install step" {
  # The real jig-init, so the URL install.sh exports is not silently skipped.
  local harness="$BATS_TEST_DIRNAME/.."
  cp "$harness/bootstrap/jig-init" "$harness/bootstrap/detect-stack.sh" "$FAKE/bootstrap/"
  cp -r "$harness/bootstrap/templates" "$FAKE/bootstrap/templates"
  cp "$harness/mise.toml" "$FAKE/mise.toml"
  mkdir -p "$FAKE/.claude-plugin"
  cp "$harness/.claude-plugin/marketplace.json" "$FAKE/.claude-plugin/"
  git -C "$FAKE" add -A
  git -C "$FAKE" -c user.name=t -c user.email=t@t commit -q -m real
  stubs="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$stubs"
  printf '#!/bin/bash\nif [ "$1" = exec ]; then shift 2; exec "$@"; fi\nexit 0\n' >"$stubs/mise"
  printf '#!/bin/bash\necho "$*" >>"%s"\n' "$BATS_TEST_TMPDIR/claude.calls" >"$stubs/claude"
  printf '#!/bin/bash\nexit 0\n' >"$stubs/codebase-memory-mcp"
  chmod +x "$stubs"/mise "$stubs"/claude "$stubs"/codebase-memory-mcp
  git init -q
  echo x >main.tf
  git add main.tf
  PATH="$stubs:$PATH" run sh "$INSTALL"
  [ "$status" -eq 0 ]
  grep -qF "plugin marketplace add file://$FAKE" "$BATS_TEST_TMPDIR/claude.calls"
  grep -qF "plugin install jig-core@jig --scope project" "$BATS_TEST_TMPDIR/claude.calls"
}

@test "JIG_HARNESS_REF pins a tag; unknown ref fails" {
  JIG_HARNESS_REF=v1 run sh "$INSTALL"
  [ "$status" -eq 0 ]
  JIG_HARNESS_REF=nope run sh "$INSTALL"
  [ "$status" -ne 0 ]
}

@test "bad clone URL fails without running jig-init" {
  JIG_HARNESS_URL="file://$BATS_TEST_TMPDIR/missing" run sh "$INSTALL"
  [ "$status" -ne 0 ]
  [ ! -e "$OUT" ]
}

@test "fails closed when git is missing" {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  for t in mktemp rm; do ln -s "$(command -v $t)" "$BATS_TEST_TMPDIR/bin/$t"; done
  PATH="$BATS_TEST_TMPDIR/bin" run "$(command -v sh)" "$INSTALL"
  [ "$status" -eq 1 ]
  [[ "$output" == *"git is required"* ]]
}
