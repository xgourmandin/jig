#!/usr/bin/env bats
# Run: bats tests/
GUARD="$BATS_TEST_DIRNAME/../plugins/jig-core/hooks/scripts/guard.sh"

bash_call() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | bash "$GUARD"; }
read_call() { jq -nc --arg p "$1" '{tool_name:"Read",tool_input:{file_path:$p}}' | bash "$GUARD"; }

@test "blocks terraform apply"            { run bash_call "terraform apply -auto-approve"; [ "$status" -eq 2 ]; }
@test "blocks chained terraform destroy"  { run bash_call "cd infra && terraform destroy"; [ "$status" -eq 2 ]; }
@test "blocks tofu apply with -chdir"     { run bash_call "tofu -chdir=envs/prod apply"; [ "$status" -eq 2 ]; }
@test "allows terraform plan"             { run bash_call "terraform plan -out=tfplan"; [ "$status" -eq 0 ]; }
@test "allows grep for 'apply' text"      { run bash_call "grep -r apply docs/"; [ "$status" -eq 0 ]; }
@test "blocks state rm"                   { run bash_call "terraform state rm aws_s3_bucket.x"; [ "$status" -eq 2 ]; }
@test "blocks git push --force"           { run bash_call "git push --force origin main"; [ "$status" -eq 2 ]; }
@test "blocks git push -f"                { run bash_call "git push -f"; [ "$status" -eq 2 ]; }
@test "allows normal git push"            { run bash_call "git push -u origin feat/x"; [ "$status" -eq 0 ]; }
@test "blocks reading .env"               { run read_call "/repo/.env"; [ "$status" -eq 2 ]; }
@test "allows reading .env.example"       { run read_call "/repo/.env.example"; [ "$status" -eq 0 ]; }
@test "blocks reading tfstate"            { run read_call "/repo/infra/terraform.tfstate"; [ "$status" -eq 2 ]; }
@test "allows reading main.tf"            { run read_call "/repo/infra/main.tf"; [ "$status" -eq 0 ]; }
