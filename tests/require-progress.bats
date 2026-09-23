#!/usr/bin/env bats
# Run: bats tests/
HOOK="$BATS_TEST_DIRNAME/../plugins/jig-core/hooks/scripts/require-progress.sh"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO/.ai/work/feat-x"
  cd "$REPO" || return 1
  git init -q -b feat/x
  echo "- [ ] task" >.ai/work/feat-x/plan.md
  echo "# Progress" >.ai/work/feat-x/progress.md
  echo "v1" >app.py
  git add -A && git -c user.name=t -c user.email=t@t commit -qm init
}

stop() { jq -nc --argjson a "${1:-false}" '{hook_event_name:"Stop",stop_hook_active:$a}' | bash "$HOOK"; }

@test "no changes: lets Claude stop" {
  run stop
  [ "$status" -eq 0 ]; [ -z "$output" ]
}
@test "code changed, work state not updated: blocks" {
  echo v2 >app.py
  run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *".ai/work/feat-x/plan.md and progress.md"* ]]
}
@test "code changed and progress updated: lets Claude stop" {
  echo v2 >app.py
  echo "## today" >>.ai/work/feat-x/progress.md
  run stop
  [ -z "$output" ]
}
@test "untracked new file counts as a code change" {
  echo new >new.py
  run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
}
@test "only work state changed: lets Claude stop" {
  echo "- [x] task" >.ai/work/feat-x/plan.md
  run stop
  [ -z "$output" ]
}
@test "stop_hook_active: never blocks twice" {
  echo v2 >app.py
  run stop true
  [ -z "$output" ]
}
@test "branch without work state: lets Claude stop" {
  git checkout -q -b other
  echo v2 >app.py
  run stop
  [ -z "$output" ]
}
