# stella.agentic.workflow.docs

A Claude Code plugin that defines the standard documentation structure used by agents to leave
durable knowledge behind between sessions.

Plugin name (kebab-case, as required by Claude Code): `stella-agentic-workflow-docs`.

## What it does

1. **Defines the structure** — a `docs/` folder with four typed areas, each indexed by its own
   `README.md`:

   ```
   docs/
   ├── README.md          # entry point, links to the indexes below
   ├── adrs/              # architectural & design decision records
   ├── plans/             # plans produced by agents, skills, or workflows
   ├── memories/          # durable facts agents learned about the repository
   └── learnings/         # lessons learned: failures, gotchas, corrections
   ```

2. **Teaches every session** — a `SessionStart` hook ([hooks/hooks.json](hooks/hooks.json))
   injects [context/docs-structure.md](context/docs-structure.md) into the context of every
   session (local CLI, desktop, or cloud), so any agent knows the layout, when to write each
   document type, and that folder indexes must be kept up to date. If the structure is missing,
   the hook says so and points at the bootstrap skill.

3. **Bootstraps the structure** — the `/stella-agentic-workflow-docs:docs-init` skill runs
   [scripts/init-docs.sh](scripts/init-docs.sh), which idempotently copies the
   [templates/docs/](templates/docs/) tree (the single source of truth for the folders and
   README index files) into the repository, never overwriting existing files.

## Document types

- **adrs/** — any record of architectural or design decisions; anything important for new and
  existing features. Written at decision time. Files: `NNNN-short-title.md`.
- **plans/** — all plans produced by agents, skills, or workflows, stored before execution and
  updated as work progresses. Files: `YYYY-MM-DD-short-title.md`.
- **memories/** — durable facts not derivable from code or git history, added whenever a session
  learns something a future session would otherwise rediscover. Files: `YYYY-MM-DD-short-title.md`.
- **learnings/** — lessons learned (failed approaches, corrections, gotchas, post-mortems),
  added whenever something didn't work as expected. Files: `YYYY-MM-DD-short-title.md`.

Document **templates are intentionally not defined yet** — they will be added later. Until then,
documents are plain markdown with a clear title and date.

## Installation

See the [repository README](../../README.md#installing-the-docs-plugin-in-a-repository) for how
to install this plugin in a repository via the `stella-agentic` marketplace.
