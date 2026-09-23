#!/usr/bin/env bash
# Starts codebase-memory-mcp as a stdio MCP server, locked down for the pilot:
# never its installer (no agent auto-config), reads limited to this project.
# The binary is pinned by the consuming repo's mise.toml.
set -euo pipefail
if ! command -v codebase-memory-mcp >/dev/null; then
  echo "jig repo map: codebase-memory-mcp is not on PATH. Pin it in mise.toml and run 'mise install'." >&2
  exit 1
fi
root="${CBM_ALLOWED_ROOT:-${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}"
export CBM_ALLOWED_ROOT="$root"
exec codebase-memory-mcp
