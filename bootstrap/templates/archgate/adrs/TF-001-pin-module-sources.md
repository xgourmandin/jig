---
id: TF-001
title: Pin module sources
domain: terraform
rules: true
files: ["**/*.tf"]
---

# Pin module sources

## Context

A module source without a version follows whatever is on the default branch, so the same code can plan differently tomorrow.

## Decision

Git module sources pin a tag or commit with `?ref=`. Registry modules set `version`.

## Do's and Don'ts

### Do

- `source = "git::https://git.example.com/infra/modules.git//vpc?ref=v1.4.0"`

### Don't

- `source = "git::https://git.example.com/infra/modules.git//vpc"`

## Consequences

Upgrades are explicit, reviewed changes.
