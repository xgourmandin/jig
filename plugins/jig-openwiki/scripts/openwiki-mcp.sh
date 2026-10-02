#!/usr/bin/env bash
# Starts OpenWiki's host-driven MCP server (stdio): OpenWiki keeps the page
# queue, Claims and finalization; Claude Code does the research and writing
# with the developer's own session, so no provider key is needed.
# `jig-init --openwiki` runs `openwiki integrations install claude` per developer.
# The package is pinned by the consuming repo's mise.toml (npm backend).
set -euo pipefail
if ! command -v openwiki >/dev/null; then
  echo "jig openwiki: openwiki is not on PATH. Pin node and npm:openwiki in mise.toml and run 'mise install'." >&2
  exit 1
fi
# Telemetry is on by default upstream.
export OPENWIKI_TELEMETRY_DISABLED=1
exec openwiki mcp --host claude
