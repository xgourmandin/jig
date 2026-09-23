# acme-claude-harness

ACME's shared Claude Code harness, distributed as a plugin marketplace. See `docs/DESIGN.md`.

## Use in a repo (target state)
```json
// <repo>/.claude/settings.json
{
  "extraKnownMarketplaces": {
    "acme": { "source": { "source": "git", "url": "https://git.acme.internal/platform/acme-claude-harness.git" } }
  },
  "enabledPlugins": {
    "acme-core@acme": true,
    "acme-terraform@acme": true
  }
}
```
Then `mise install` and `claude plugin install acme-core@acme --scope project` (to be automated by `bootstrap/acme-init`).

## Develop
`mise install && mise run test && mise run lint`, then `claude --plugin-dir ./plugins/acme-core --plugin-dir ./plugins/acme-terraform` in a sample repo.
