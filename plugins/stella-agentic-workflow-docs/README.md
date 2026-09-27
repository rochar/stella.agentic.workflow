# stella.agentic.workflow.docs

A Claude Code plugin that defines the standard documentation structure used by agents to leave
durable knowledge behind between sessions.

Plugin name (kebab-case, as required by Claude Code): `stella-agentic-workflow-docs`.

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
   [templates/docs/](templates/docs/) (scaffold files, part files, template fields, sections
   and vocabularies, index-line formats) and with `--fix` repairs the scaffold — creating
   missing files, restoring drifted templates, refreshing folder README prose while keeping
   index lines, and removing templates the plugin no longer ships. The skill then migrates
   records to the current layout (e.g. a plan's old `problem.md` into a spec), adopts
   decisions, plans, and lessons kept elsewhere as records, and fixes index lines — moving
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

- **adrs/** — any record of architectural or design decisions; anything important for new and
  existing features. Written at decision time. Layout: directory `NNNN-slug/` with `problem.md`,
  `decision.md`, `log.md`.
- **specs/** — specifications of what to build and why: objective, scope, requirements,
  acceptance criteria. Layout: directory `NNNN-slug/` with `spec.md`.
- **plans/** — plans produced by agents, skills, or workflows: how something will be built
  (approach, checkbox steps, verification), naming the spec it implements, if any. Layout:
  directory `NNNN-slug/` with `plan.md`.
- **memories/** — durable facts not derivable from code or git history, added whenever a session
  learns something a future session would otherwise rediscover. Each memory declares a type and
  carries a `Verified:` date updated whenever the fact is confirmed to still hold; the type
  vocabulary and qualification rules live in `memories/README.md`. Files: `NNNN-slug.md`.
- **learnings/** — lessons learned (failed approaches, corrections, gotchas, post-mortems),
  added when something didn't work as expected and the qualification rules in
  `learnings/README.md` hold. Files: `NNNN-slug.md`.

Records are identified by a zero-padded per-folder sequence number (starting at `0001`) plus a
kebab-case slug of at most 4 words (noun-phrase for ADRs and specs, verb-phrase for plans);
dates live in each folder's `README.md` index line, not in filenames. The index-line format is
defined in each folder's `README.md` (ADR, spec, and plan index lines carry a status, memory
index lines carry a type). Statuses have defined vocabularies and reading rules — only accepted
ADRs bind; implemented specs and done or abandoned plans are history — documented in the
folder `README.md`s. Splitting ADRs into fixed-name part files lets agents load only the part
they need (e.g. `decision.md` without the growing `log.md`).

The templates define the shape of each record, not a workflow: nothing requires a spec before
a plan, or a plan for every spec. How records are produced — spec-first gates, human approval,
task breakdown — is left to the skills and workflows that use the structure.

The contents of each document are defined by standalone `<part>.template.md` files that live in
the folder they apply to (bootstrapped together with the tree): `problem`/`decision`/`log` for
ADRs, `spec` for specs, `plan` for plans, and one template each for memories and learnings. Every
document starts as a copy of its template; template files are not records and are never indexed.

## Installation

See the [repository README](../../README.md#installation) for how
to install this plugin in a repository via the `stella-agentic` marketplace.
