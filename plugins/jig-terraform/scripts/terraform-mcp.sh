#!/usr/bin/env bash
# Starts HashiCorp terraform-mcp-server (stdio) with only the public registry
# toolset: provider/module docs, no HCP Terraform/TFE workspace operations.
# The binary is pinned by the consuming repo's mise.toml (go backend).
set -euo pipefail
if ! command -v terraform-mcp-server >/dev/null; then
  echo "jig terraform: terraform-mcp-server is not on PATH. Pin it in mise.toml and run 'mise install'." >&2
  exit 1
fi
exec terraform-mcp-server stdio --toolsets=registry --log-level warn
