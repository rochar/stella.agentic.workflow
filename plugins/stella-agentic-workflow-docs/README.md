# stella.agentic.workflow.docs

A Claude Code plugin that defines the standard documentation structure used by agents to leave
durable knowledge behind between sessions.

Plugin name (kebab-case, as required by Claude Code): `stella-agentic-workflow-docs`.

Visual overview (Mermaid diagrams of every artifact, the session flow, and the `docs/`
organisation): [stella-agentic-workflow-docs.md](../../stella-agentic-workflow-docs.md).

## What it does

1. **Defines the structure** — a `docs/` folder with five typed areas, each indexed by its own
   `README.md`:

   ```
   docs/
   ├── README.md          # entry point, links to the indexes below
   ├── adrs/              # architectural & design decision records
   ├── specs/             # specifications: what to build and why
   ├── plans/             # plans: how to build it
   ├── memories/          # durable facts agents learned about the repository
   └── learnings/         # lessons learned: failures, gotchas, corrections
   ```

2. **Teaches every session** — a `SessionStart` hook ([hooks/hooks.json](hooks/hooks.json))
   injects [context/docs-structure.md](context/docs-structure.md) into the context of every
   session (local CLI, desktop, or cloud), so any agent knows the layout, when to write each
   document type, and that folder indexes must be kept up to date. If the structure is missing,
   the hook says so and points at the bootstrap skill (or, when only some of it is present —
   typically a bootstrap from an older plugin version — at the `docs-doctor` skill).

3. **Nudges capture once per session** — a `Stop` hook
   ([hooks-handlers/stop.sh](hooks-handlers/stop.sh)) asks the agent to record anything durable
   the session produced (decision, spec, plan, memory, or learning) and update the folder index.
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

5. **Reconciles the tree with the conventions** — the
   `/stella-agentic-workflow-docs:docs-doctor` skill ([skills/docs-doctor/SKILL.md](skills/docs-doctor/SKILL.md))
   is for adding the plugin to a repository with existing docs, for plugin updates, and for
   records written without following the structure. It runs
   [scripts/doctor-docs.sh](scripts/doctor-docs.sh), which derives its checks from
   [templates/docs/](templates/docs/) (scaffold files, front-matter fields, sections
   and vocabularies, index-line formats) and with `--fix` repairs the scaffold — creating
   missing files, restoring drifted templates, refreshing folder README prose while keeping
   index lines, and removing templates the plugin no longer ships. The skill then migrates
   records to the current layout (e.g. an old ADR directory into one `ADR-YYYYMMDD-slug.md`,
   or a sequence-numbered record to its date-based name), adopts decisions, plans, and
   lessons kept elsewhere as records, and fixes index lines — moving
   content, never dropping it, and never inventing what no evidence supports. Stray
   documentation that is not a record is left alone. It never commits. The script alone
   exits non-zero when `docs/` does not conform, so it can also gate CI.

6. **Gardens the tree on demand** — the `/stella-agentic-workflow-docs:docs-gc` skill
   ([skills/docs-gc/SKILL.md](skills/docs-gc/SKILL.md)) reviews what the records say, once
   `doctor-docs.sh` reports the structure clean (otherwise it defers to `docs-doctor`): it
   re-verifies or retires stale memories, marks obsolete learnings, merges near-duplicates,
   updates dead spec and plan statuses, and tightens prose — always following the folder
   READMEs' retirement rules (retired records keep their index lines; only memory files are
   ever deleted; ADRs, specs, and plans are never removed), never editing the scaffold, and
   never committing: the diff is left for human review.

## Document types

Every record is one file `<PREFIX>-YYYYMMDD-slug.md` starting with YAML front matter.

- **adrs/** (`ADR-`) — architectural or design decisions; anything important for new and
  existing features. Written at decision time. Body: `## Context` and `## Decision`.
- **specs/** (`SPEC-`) — what to build and why: objective, scope, requirements, acceptance
  criteria.
- **plans/** (`PLAN-`) — how something will be built (approach, checkbox steps, verification),
  naming the spec it implements and the ADRs it relies on, if any.
- **memories/** (`MEM-`) — durable facts not derivable from code or git history. Each declares
  a type and carries a `verified:` date updated whenever the fact is confirmed to still hold;
  the type vocabulary and qualification rules live in `memories/README.md`.
- **learnings/** (`LRN-`) — lessons learned (failed approaches, corrections, gotchas,
  post-mortems), added when the qualification rules in `learnings/README.md` hold.

Records are identified by their prefix, their creation date (`YYYYMMDD`, equal to the
`date:` field), and a kebab-case slug of at most 4 words (noun-phrase for ADRs and specs,
verb-phrase for plans) — e.g. `ADR-20261003-use-postgres.md`; the whole file stem is the id.
Dates rather than sequence numbers mean parallel branches never claim the same id. The front
matter holds the id, status or type, dates, and a one-line `summary`, so an agent can judge a
record without reading its body. The index-line format is defined in each folder's
`README.md` (ADR, spec, and plan index lines carry a status, memory index lines carry a
type). Statuses have defined vocabularies and
reading rules — only accepted ADRs bind; implemented specs and done or abandoned plans are
history — documented in the folder `README.md`s.

The templates define the shape of each record, not a workflow: nothing requires a spec before
a plan, or a plan for every spec. How records are produced — spec-first gates, human approval,
task breakdown — is left to the skills and workflows that use the structure.

Each record type is defined by one `<type>.template.md` in its folder (bootstrapped together
with the tree): `adr`, `spec`, `plan`, `memory`, `learning`. Every record starts as a copy of
its template; template files are not records and are never indexed.

## Installation

See the [repository README](../../README.md#installation) for how
to install this plugin in a repository via the `stella-agentic` marketplace.
