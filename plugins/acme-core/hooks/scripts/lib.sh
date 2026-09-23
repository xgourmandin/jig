#!/usr/bin/env bash
# Shared helpers for ACME hook scripts.

# Work-state folder for the current branch: <repo>/.ai/work/<branch, "/" -> "-">
acme_work_dir() {
  local root branch
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
  branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 1
  printf '%s/.ai/work/%s\n' "$root" "${branch//\//-}"
}
