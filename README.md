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
Then `mise install` and `claude plugin install jig-core@jig --scope project` (to be automated by `bootstrap/jig-init`).

## Develop
`mise install && mise run test && mise run lint`, then `claude --plugin-dir ./plugins/jig-core --plugin-dir ./plugins/jig-terraform` in a sample repo.
