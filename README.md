# jig-claude-harness

Jig's shared Claude Code harness, distributed as a plugin marketplace. See `docs/DESIGN.md`.

## Use in a repo (target state)
```json
// <repo>/.claude/settings.json
{
  "extraKnownMarketplaces": {
    "jig": { "source": { "source": "git", "url": "https://git.example.com/TODO/jig-claude-harness.git" } }
  },
  "enabledPlugins": {
    "jig-core@jig": true,
    "jig-terraform@jig": true
  }
}
```
`bootstrap/jig-init [--marketplace-url URL|DIR] [--tofu] [--openwiki] [--no-install] [repo]` writes this plus `mise.toml`, `CLAUDE.md`, `docs/ai/ARCHITECTURE.md`, `.claude/rules/terraform.md`, first ADRs in `.archgate/adrs/`, and optionally enables `jig-openwiki` (a generated wiki refreshed locally by Claude Code, no API key). It never overwrites existing files. Every developer runs it once after cloning: it also runs `mise install` and `claude plugin install … --scope project`.

Claude Code must start with the mise tools on PATH (`mise activate` in your shell).

## Develop
`mise install && mise run test && mise run lint`, then `claude --plugin-dir ./plugins/jig-core --plugin-dir ./plugins/jig-terraform` in a sample repo.
