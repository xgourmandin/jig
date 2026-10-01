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
