#!/usr/bin/env bats
# Run: bats tests/   (needs terraform and tflint from `mise install`)
SCRIPTS="$BATS_TEST_DIRNAME/../plugins/jig-terraform/hooks/scripts"
FIXTURE="$BATS_TEST_DIRNAME/fixtures/tf-sample"

setup() {
  REPO="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cp -r "$FIXTURE/." "$REPO/"
  rm -rf "$REPO/.terraform" "$REPO/modules/naming/.terraform"
  cd "$REPO" || return 1
  git init -q -b main
  export CLAUDE_PLUGIN_DATA="$BATS_TEST_TMPDIR/data"
  STATE="$CLAUDE_PLUGIN_DATA/sessions/s1.dirs"
}

edit()  { jq -nc --arg f "$1" '{session_id:"s1",tool_name:"Edit",tool_input:{file_path:$f}}' | bash "$SCRIPTS/tf-post-edit.sh"; }
stop()  { jq -nc --argjson a "${1:-false}" '{session_id:"s1",hook_event_name:"Stop",stop_hook_active:$a}' | bash "$SCRIPTS/tf-stop-validate.sh"; }
break_module() { printf 'output "broken" {\n  value = var.nope\n}\n' >>"$REPO/outputs.tf"; }

# Directory of fake binaries, to control what is "installed".
stub_bin() {
  STUBS="$BATS_TEST_TMPDIR/stubs"; mkdir -p "$STUBS"
  for b in "$@"; do printf '#!/bin/sh\nexit 0\n' >"$STUBS/$b"; chmod +x "$STUBS/$b"; done
  for b in bash jq git grep mkdir dirname cat head sort cut cksum rm mv cp mktemp; do
    ln -sf "$(command -v "$b")" "$STUBS/$b"
  done
}

# --- lib: binary selection ---------------------------------------------------
@test "tf bin: terraform by default" {
  stub_bin terraform tofu
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_tf_bin"
  [ "$output" = terraform ]
}
@test "tf bin: tofu when .opentofu-version exists" {
  stub_bin terraform tofu; touch .opentofu-version
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_tf_bin"
  [ "$output" = tofu ]
}
@test "tf bin: tofu when mise.toml pins opentofu" {
  stub_bin terraform tofu; printf '[tools]\nopentofu = "1.10.0"\n' >mise.toml
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_tf_bin"
  [ "$output" = tofu ]
}
@test "tf bin: tofu when it is the only one installed" {
  stub_bin tofu
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_tf_bin"
  [ "$output" = tofu ]
}
@test "tf bin: fails when the repo wants tofu but only terraform exists" {
  stub_bin terraform; touch .opentofu-version
  run env PATH="$STUBS" bash -c "source '$SCRIPTS/lib.sh'; jig_tf_bin"
  [ "$status" -ne 0 ]
}

# --- PostToolUse: tf-post-edit.sh ----------------------------------------------
@test "post-edit: ignores non-Terraform files" {
  echo x >README.md
  run edit "$REPO/README.md"
  [ "$status" -eq 0 ]
  [ ! -e "$STATE" ]
}
@test "post-edit: clean .tf passes and records its module dir" {
  run edit "$REPO/modules/naming/main.tf"
  [ "$status" -eq 0 ]
  [ "$(cat "$STATE")" = "$REPO/modules/naming" ]
  run edit "$REPO/modules/naming/main.tf"
  [ "$(wc -l <"$STATE")" -eq 1 ]
}
@test "post-edit: formats the file" {
  printf 'variable "x" {\ntype=string\n}\n' >extra.tf
  run edit "$REPO/extra.tf"
  grep -q '  type = string' extra.tf
}
@test "post-edit: syntax error blocks with fmt message" {
  printf 'variable "x" {\n' >bad.tf
  run edit "$REPO/bad.tf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"terraform fmt failed"* ]]
}
@test "post-edit: tflint finding blocks" {
  printf 'variable "unused" {}\n' >lint.tf
  run edit "$REPO/lint.tf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"tflint reported issues"* ]]
}
@test "post-edit: uses the nearest .tflint.hcl up the tree" {
  mkdir -p live/dev
  cat >live/dev/main.tf <<'HCL'
terraform {
  required_version = ">= 1.9"
}

variable "BadName" {
  type        = string
  description = "Camel case."
}

output "o" {
  description = "Echo."
  value       = var.BadName
}
HCL
  run edit "$REPO/live/dev/main.tf"
  [ "$status" -eq 0 ]
  cp "$BATS_TEST_DIRNAME/../bootstrap/templates/tflint/.tflint.hcl" .tflint.hcl
  run edit "$REPO/live/dev/main.tf"
  [ "$status" -eq 2 ]
  [[ "$output" == *"terraform_naming_convention"* ]]
}
@test "post-edit: fails open when no tools are installed" {
  stub_bin
  printf 'variable "x" {\n' >bad.tf
  PATH="$STUBS" run edit "$REPO/bad.tf"
  [ "$status" -eq 0 ]
  [ -s "$STATE" ]
}

# --- Stop: tf-stop-validate.sh -------------------------------------------------
@test "stop: nothing edited, nothing to do" {
  run stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
@test "stop: valid module passes, clears the list, leaves no files in the repo" {
  edit "$REPO/main.tf"
  run stop
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$STATE" ]
  [ ! -e "$REPO/.terraform" ]
  [ ! -e "$REPO/.terraform.lock.hcl" ]
}
@test "stop: invalid module blocks once and keeps the list" {
  edit "$REPO/main.tf"
  break_module
  run stop
  [ "$status" -eq 0 ]
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"var.nope"* ]]
  [ -s "$STATE" ]
}
@test "stop: re-check after a block reports but never blocks twice" {
  edit "$REPO/main.tf"
  break_module
  run stop true
  [ "$status" -eq 0 ]
  [ "$(jq -r '.decision // empty' <<<"$output")" = "" ]
  [[ "$(jq -r .systemMessage <<<"$output")" == *"checks still fail after Claude's fix"*"var.nope"* ]]
  [ -s "$STATE" ]
}
@test "stop: re-check after a block passes silently and clears the list" {
  edit "$REPO/main.tf"
  run stop true
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$STATE" ]
}
@test "stop: existing lock file is restored byte for byte" {
  printf '# lock placeholder\n' >.terraform.lock.hcl
  edit "$REPO/main.tf"
  run stop
  [ "$(cat .terraform.lock.hcl)" = "# lock placeholder" ]
}
@test "stop: missing binary warns instead of blocking" {
  edit "$REPO/main.tf"
  JIG_TF_BIN=no-such-tf run stop
  [ "$status" -eq 0 ]
  [ -n "$(jq -r .systemMessage <<<"$output")" ]
  [ "$(jq -r '.decision // empty' <<<"$output")" = "" ]
}
@test "stop: OpenTofu repo validates with tofu" {
  touch .opentofu-version
  edit "$REPO/main.tf"
  break_module
  run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(tofu validate)"* ]]
}
@test "stop: trivy HIGH finding blocks (validate stubbed, no provider download)" {
  stub_bin fake-tf
  printf 'resource "aws_security_group" "ssh" {\n  ingress {\n    from_port   = 22\n    to_port     = 22\n    protocol    = "tcp"\n    cidr_blocks = ["0.0.0.0/0"]\n  }\n}\n' >sg.tf
  edit "$REPO/sg.tf" || true
  PATH="$STUBS:$PATH" JIG_TF_BIN=fake-tf run stop
  [ "$(jq -r .decision <<<"$output")" = block ]
  [[ "$(jq -r .reason <<<"$output")" == *"(trivy config)"*"AWS-0107"* ]]
}

@test "stop: lint task present -> trivy skipped, validate still runs" {
  stub_bin fake-tf
  printf 'resource "aws_security_group" "ssh" {\n  ingress {\n    from_port   = 22\n    to_port     = 22\n    protocol    = "tcp"\n    cidr_blocks = ["0.0.0.0/0"]\n  }\n}\n' >sg.tf
  edit "$REPO/sg.tf" || true
  printf '[tasks.lint]\nrun = "true"\n' >mise.toml
  printf '#!/bin/sh\nexit 0\n' >"$STUBS/mise"; chmod +x "$STUBS/mise"
  PATH="$STUBS:$PATH" JIG_TF_BIN=fake-tf run stop
  [ -z "$output" ]
}

# --- MCP wrapper: scripts/terraform-mcp.sh -------------------------------------
@test "terraform mcp: fails with a clear message when the binary is missing" {
  stub_bin
  run env PATH="$STUBS" bash "$SCRIPTS/../../scripts/terraform-mcp.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not on PATH"* ]]
}
@test "terraform mcp: starts stdio with the registry toolset only" {
  stub_bin
  printf '#!/bin/sh\necho "$@"\n' >"$STUBS/terraform-mcp-server"; chmod +x "$STUBS/terraform-mcp-server"
  run env PATH="$STUBS" bash "$SCRIPTS/../../scripts/terraform-mcp.sh"
  [ "$output" = "stdio --toolsets=registry --log-level warn" ]
}
