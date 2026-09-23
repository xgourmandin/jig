#!/usr/bin/env bash
# PreToolUse guardrail. Reads the hook JSON on stdin.
# Exit 2 + message on stderr = block the tool call and tell Claude why.
set -uo pipefail
input="$(cat)"

block() { echo "ACME guardrail: $1" >&2; exit 2; }

# Fail closed for shell commands if jq is missing: a guardrail that silently
# disappears is worse than one that asks for its dependency.
if ! command -v jq >/dev/null; then
  if grep -Eq '"tool_name"[[:space:]]*:[[:space:]]*"Bash"' <<<"$input"; then
    block "jq is not installed, so shell commands cannot be checked. Ask the user to run 'mise install'."
  fi
  exit 0
fi

tool="$(jq -r '.tool_name // empty' <<<"$input")"

case "$tool" in
  Bash)
    cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
    # Infrastructure changes are applied by CI, never from an AI session.
    if grep -Eq '(^|[;&|[:space:]])(terraform|tofu|terragrunt)[[:space:]]+([^;&|]*[[:space:]])?(apply|destroy|import)([[:space:]]|$)' <<<"$cmd"; then
      block "terraform/tofu apply, destroy and import are not allowed from Claude sessions. Run 'plan' and let the pipeline apply."
    fi
    if grep -Eq '(terraform|tofu)[[:space:]]+state[[:space:]]+(rm|mv|push|replace-provider)' <<<"$cmd"; then
      block "terraform state mutation is not allowed from Claude sessions."
    fi
    if grep -Eq 'git[[:space:]]+push[^;&|]*([[:space:]]--force|[[:space:]]-f([[:space:]]|$)|[[:space:]]\+[^[:space:]]+)' <<<"$cmd"; then
      block "force-push is not allowed. Ask the human to do it if really needed."
    fi
    # shellcheck disable=SC2016  # literal $HOME is intended
    if grep -Eq 'rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+(/|~|\$HOME)/?([[:space:]]|$)' <<<"$cmd"; then
      block "refusing recursive delete of / or home."
    fi
    ;;
  Read|Edit|Write)
    path="$(jq -r '.tool_input.file_path // empty' <<<"$input")"
    base="$(basename -- "$path")"
    case "$base" in
      .env.example|.env.sample|.env.template) ;;
      .env|.env.*) block "access to $base is blocked (may contain secrets)." ;;
      *.tfstate|*.tfstate.backup) block "access to Terraform state ($base) is blocked: state contains secrets. Use 'terraform state list' / 'terraform show' on a sanitized plan instead." ;;
      *.pem|*.key|*.p12|*.pfx|id_rsa|id_ed25519) block "access to key material ($base) is blocked." ;;
    esac
    ;;
esac
exit 0
