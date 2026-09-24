# jig-openwiki

Opt-in (`jig-init --openwiki`). Keeps a generated, human-reviewed wiki of the repo in `openwiki/` with [OpenWiki](https://github.com/langchain-ai/openwiki) (MIT).

Runs **locally, driven by Claude Code**: OpenWiki's host-driven mode keeps the page queue, Grounded Claims and finalization, and Claude Code researches and writes each page with the developer's own Claude session. The developer asks "update this repository's OpenWiki" on a branch and the result goes through a normal PR.

| Component | File | What it does |
|---|---|---|
| MCP | `.mcp.json`, `scripts/openwiki-mcp.sh` | `openwiki mcp --host claude` (page-job lifecycle tools `openwiki_begin` … `openwiki_finish`), telemetry off |
| Skill | `skills/openwiki` | Jig rules (branch, confirm before `init`, PR review) + the upstream OpenWiki skill for openwiki 0.5.2 |

We do not use `openwiki integrations install claude`: it writes `~/.claude.json` and user-level skills outside the harness.

Requires `node` (≥ 22.22) and `npm:openwiki` on PATH (pinned in the repo's `mise.toml` by `jig-init --openwiki`). Refresh `skills/openwiki/SKILL.md` from the package when bumping the pin.
