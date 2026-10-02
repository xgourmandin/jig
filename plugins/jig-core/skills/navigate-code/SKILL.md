---
name: navigate-code
description: How to find code in a Jig repo without grepping the whole tree. Use before searching for where something is defined, used, called or configured, or when exploring an unfamiliar part of the repo.
user-invocable: false
---

# Navigating code

Use the cheapest tool that answers the question, in this order. Move down only when the one above cannot answer.

1. **Repo map** (MCP server `repo-map`, codebase-memory-mcp): structure and relationships across the whole repo, including infrastructure code (HCL).
   - Where is X / what is there: `search_graph` (name or label pattern), `get_architecture` (aspects `overview`) for a first look at an unfamiliar repo.
   - Who calls X / what X depends on: `trace_path`.
   - Read one symbol: `get_code_snippet` instead of reading the whole file.
   - If the session context says there is no graph, run `index_repository` (mode `fast`) once first.
2. **LSP** (the LSP tool, when a language server is enabled): exact go-to-definition, find-references, hover types, diagnostics for a symbol you already have a position for. More precise than the graph inside one language.
3. **ast-grep** (`ast-grep run -p '<pattern>' -l <lang> <path>`): structural search when you need a code _shape_ (every call to `foo($A)` with two args, every resource with a given block). Also for mechanical codemods (`--rewrite`).
4. **grep / Grep tool**: plain text only (log messages, config keys, comments, strings), scoped to a directory or glob. Never as the first step for "where is this defined/used".

Rules:

- Don't read whole large files to find one function; get the snippet or use the LSP.
- When a tool is unavailable (MCP server failed, no LSP for this language), say so once and move to the next step.
- Share what you learned about repo structure in `docs/ai/ARCHITECTURE.md` only when the user asks; the graph already covers "where things are".
