---
name: adrs
description: Read and respect this repo's architecture decisions (Archgate ADRs in .archgate/adrs/) before changing code, check compliance after, and propose a new ADR when a lasting decision is made. Use before non-trivial code changes in a repo that has .archgate/, and when the user makes or asks about an architecture decision.
---

# Architecture decisions (Archgate)

The repo's ADRs live in `.archgate/adrs/<ID>-<slug>.md`, some with a companion `.rules.ts` that `archgate check` enforces in `mise run lint` and CI. Use the `archgate` CLI only; the Archgate Claude Code plugin needs an account and is not used at Jig. Telemetry is off via `ARCHGATE_TELEMETRY=0` in the repo's `mise.toml`.

**Before changing code**
- `archgate review-context` lists the ADRs relevant to your changed files (add `--verbose` for each ADR's decision and do's/don'ts). Nothing changed yet: `archgate adr list`, then `archgate adr show <ID>` for the ones in your domain.
- If the requested change contradicts an ADR, say so and ask before proceeding. Don't silently work around it.

**After changing code**
- Run `archgate check` (JSON output; exit 1 on a violation). Fix violations. Don't edit a `.rules.ts` to make your change pass unless the user asked to change the decision.

**Proposing a new ADR**
- When the user settles a decision that will constrain future code (a library choice, a layout, a boundary, a naming or security rule), offer to record it. Never add one unasked.
- Draft with `archgate adr create`, or write the file by hand using the existing ADRs' frontmatter (`id`, `title`, `domain`, `rules`, optional `files` globs) and sections: Context, Decision, Do's and Don'ts, Consequences. Keep it under a page.
- Add a `.rules.ts` only when the rule can be checked mechanically without false positives, and prove it: run `archgate check` against a violating example and a compliant one.
- Don't write ADRs for things a formatter or linter already enforces.
