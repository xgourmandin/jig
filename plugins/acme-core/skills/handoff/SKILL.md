---
name: handoff
description: Bring the branch work state up to date so another person or session can resume. Use at the end of a session, before switching task, or when the user says "handoff", "wrap up", "save where we are".
---

# Handoff

1. Tick completed tasks in `.ai/work/<branch>/plan.md`; add newly discovered tasks.
2. Append a dated entry to `progress.md`: Done, Decisions (with the why), Next (the exact next action), Blockers, and commands needed to reproduce state (e.g. `terraform init -backend=false`).
3. Run the project's lint/test task and report the real result; do not guess.
4. List uncommitted changes. Do not commit or push unless the user asks.
