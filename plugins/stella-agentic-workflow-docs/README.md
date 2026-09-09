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

3. **Nudges capture once per session** — a `Stop` hook
   ([hooks-handlers/stop.sh](hooks-handlers/stop.sh)) asks the agent to record anything durable
   the session produced (decision, plan, memory, or learning) and update the folder index.
   Claude Code fires `Stop` at the end of every assistant turn, so the hook keeps a per-session
   marker (keyed on the payload's `session_id`) and nudges only the session's first stop. It
   only fires when the `docs/` structure is fully bootstrapped, tells the agent explicitly to
   finish without inventing records when nothing qualifies, and never blocks the same stop
   twice.

4. **Bootstraps the structure** — the `/stella-agentic-workflow-docs:docs-init` skill runs
   [scripts/init-docs.sh](scripts/init-docs.sh), which idempotently copies the
   [templates/docs/](templates/docs/) tree (the single source of truth for the folders, their
   README index files, and the `*.template.md` document templates) into the repository, never
   overwriting existing files.

5. **Gardens the tree on demand** — the `/stella-agentic-workflow-docs:docs-gc` skill
   ([skills/docs-gc/SKILL.md](skills/docs-gc/SKILL.md)) reviews the records: it fixes index
   drift, re-verifies or retires stale memories, marks obsolete learnings, merges
   near-duplicates, updates dead plan statuses, and tightens prose — always following the
   folder READMEs' retirement rules (retired records keep their index lines; only memory
   files are ever deleted; ADRs and plans are never removed), never editing the scaffold,
   and never committing: the diff is left for human review.

## Document types

- **adrs/** — any record of architectural or design decisions; anything important for new and
  existing features. Written at decision time. Layout: directory `NNNN-slug/` with `problem.md`,
  `decision.md`, `log.md`.
- **plans/** — all plans produced by agents, skills, or workflows, stored before execution and
  updated as work progresses. Layout: directory `NNNN-slug/` with `problem.md`, `plan.md`.
- **memories/** — durable facts not derivable from code or git history, added whenever a session
  learns something a future session would otherwise rediscover. Each memory declares a type and
  carries a `Verified:` date updated whenever the fact is confirmed to still hold; the type
  vocabulary and qualification rules live in `memories/README.md`. Files: `NNNN-slug.md`.
- **learnings/** — lessons learned (failed approaches, corrections, gotchas, post-mortems),
  added when something didn't work as expected and the qualification rules in
  `learnings/README.md` hold. Files: `NNNN-slug.md`.

Records are identified by a zero-padded per-folder sequence number (starting at `0001`) plus a
kebab-case slug of at most 4 words (noun-phrase for ADRs, verb-phrase for plans); dates live in
each folder's `README.md` index line, not in filenames. The index-line format is defined in
each folder's `README.md` (ADR and plan index lines carry a status, memory index lines carry a
type). Statuses have defined vocabularies and reading rules — only accepted ADRs bind, done or
abandoned plans are history — documented in the folder `README.md`s. Splitting ADRs
and plans into fixed-name part files lets agents load only the part they need (e.g.
`decision.md` without the growing `log.md`).

The contents of each document are defined by standalone `<part>.template.md` files that live in
the folder they apply to (bootstrapped together with the tree): `problem`/`decision`/`log` for
ADRs, `problem`/`plan` for plans, and one template each for memories and learnings. Every
document starts as a copy of its template; template files are not records and are never indexed.

## Installation

See the [repository README](../../README.md#installation) for how
to install this plugin in a repository via the `stella-agentic` marketplace.
