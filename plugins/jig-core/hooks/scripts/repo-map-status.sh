#!/usr/bin/env bash
# SessionStart: one short line about the repo map (codebase-memory-mcp), so
# Claude queries the graph before grepping. One CLI call (~2-5 s); fails open.
set -uo pipefail
command -v codebase-memory-mcp >/dev/null || exit 0
root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

# Project name as codebase-memory-mcp derives it from the path.
project="$(sed -E 's/[^A-Za-z0-9]+/-/g; s/^-+//; s/-+$//' <<<"$root")"
status="$(CBM_ALLOWED_ROOT="$root" timeout 15 codebase-memory-mcp cli --quiet index_status --project "$project" 2>/dev/null)"
nodes="$(awk '$1=="nodes:"{print $2; exit}' <<<"$status")"
when="$(awk '$1=="indexed_at:"{print $2; exit}' <<<"$status")"

echo "## Jig repo map"
if [[ -n "$nodes" ]]; then
  echo "Code graph for this repo: project \`$project\`, $nodes nodes, indexed $when."
  echo "Find code with the repo-map MCP tools (search_graph, trace_path, get_code_snippet, get_architecture) before grep; see the navigate-code skill."
else
  # No committed snapshot in the pilot: restore from graph.db.zst was not
  # observed in v0.11.0, and a fast index takes seconds.
  echo "No code graph yet for this repo. Before broad code searches, call the repo-map MCP tool index_repository with repo_path \"$root\" and mode \"fast\" (takes seconds). It then stays up to date by itself."
fi
