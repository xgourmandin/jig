# Instructions for Claude Code

This repo uses the Jig harness (plugins from the `jig` marketplace, see `.claude/settings.json`).

@docs/ai/ARCHITECTURE.md

## Commands
- `mise install`: install the pinned tools
- `mise run lint`: the same checks CI runs

## Rules
- Work state for the current branch lives in `.ai/work/<branch>/` (spec, plan, progress). Keep it up to date.
- TODO: add the few rules Claude gets wrong in this repo. Keep this file short.
