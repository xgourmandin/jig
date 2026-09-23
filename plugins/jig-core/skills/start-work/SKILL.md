---
name: start-work
description: Create the shared work-state folder (spec, plan, progress) for the current branch. Use when starting a feature, fix or infra change that will span more than one session, or when the user says "start work on", "new ticket", "plan this".
---

# Start work

Create `.ai/work/<branch>/` at the repo root (branch name with `/` replaced by `-`), then:

1. Ask the user for the ticket id and goal if not given. Do not invent acceptance criteria.
2. Write `spec.md`: ticket link, goal, scope / out of scope, acceptance criteria, constraints (for infra: "no apply, CI applies").
3. Explore only as much as needed (LSP and the repo map before grep), then write `plan.md` as a checkbox list (`- [ ] task — verified by: ...`). Each task must be finishable and verifiable in one sitting.
4. Write `progress.md` with a first entry:
   ```
   ## YYYY-MM-DD — <author or "claude">
   Done: created spec and plan
   Decisions: ...
   Next: <first task>
   Blockers: none
   ```
5. Show the plan to the user and wait for approval before implementing.

These files are committed on the branch so colleagues and later sessions can resume. Keep them short and factual.
