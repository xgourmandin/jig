#!/usr/bin/env bats
# Run: bats tests/
HOOK="$BATS_TEST_DIRNAME/../plugins/jig-core/hooks/scripts/session-start.sh"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cd "$REPO" || return 1
  git init -q -b feat/x
  git -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
  WORK="$REPO/.ai/work/feat-x"
}

write_plan() {
  mkdir -p "$WORK"
  cat >"$WORK/plan.md" <<'EOF'
# Plan

## Phase 0: done phase
- [x] old task

## Phase 1: current phase
- [x] finished task
- [ ] next task
- [ ] later task

## Phase 2: future phase
- [ ] future task
EOF
}

start() { jq -nc --arg s "$1" '{hook_event_name:"SessionStart",source:$s}' | bash "$HOOK"; }

@test "no work state: points to start-work skill" {
  run start startup
  [ "$status" -eq 0 ]
  [[ "$output" == *"Branch: feat/x"* ]]
  [[ "$output" == *"No work state for this branch (.ai/work/feat-x)"* ]]
}

@test "startup: plan counts and next task, no phase dump" {
  write_plan
  run start startup
  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan: 2 done, 3 open."* ]]
  [[ "$output" == *"Next open task: next task"* ]]
  [[ "$output" != *"Context was just compacted"* ]]
}

@test "compact: re-injects only the current phase" {
  write_plan
  run start compact
  [ "$status" -eq 0 ]
  [[ "$output" == *"Context was just compacted"* ]]
  [[ "$output" == *"## Phase 1: current phase"* ]]
  [[ "$output" == *"- [ ] later task"* ]]
  [[ "$output" != *"Phase 0"* ]]
  [[ "$output" != *"future task"* ]]
}

@test "compact with every task done: no phase section" {
  mkdir -p "$WORK"
  printf '## Phase 0\n- [x] a\n' >"$WORK/plan.md"
  run start compact
  [ "$status" -eq 0 ]
  [[ "$output" == *"Plan: 1 done, 0 open."* ]]
  [[ "$output" != *"Context was just compacted"* ]]
}

@test "only asks to read files that exist" {
  write_plan
  run start startup
  [[ "$output" == *"Read .ai/work/feat-x/plan.md before starting"* ]]
  [[ "$output" != *"spec.md"* ]]
  echo "# Spec" >"$WORK/spec.md"
  run start startup
  [[ "$output" == *"Read .ai/work/feat-x/spec.md and .ai/work/feat-x/plan.md before starting"* ]]
}

@test "shows the last progress entry only" {
  mkdir -p "$WORK"
  printf '# Progress\n\n## day 1\nold\n\n## day 2\nnewest\n' >"$WORK/progress.md"
  run start startup
  [[ "$output" == *"newest"* ]]
  [[ "$output" != *"day 1"* ]]
}

@test "outside a git repo: silent" {
  cd "$BATS_TEST_TMPDIR" && mkdir -p nogit && cd nogit
  GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR" run start startup
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "works with empty stdin" {
  write_plan
  run bash "$HOOK" </dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"Next open task: next task"* ]]
}
