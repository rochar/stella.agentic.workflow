# Agentic Workflow

`stella.agentic.workflow` is a common framework for managing agentic workflows across
repositories (documentation structure, decisions, memories, plugins, hooks, workflow state), so
AI agents behave consistently across sessions and projects.

- **Other repos consume this one.** Prefer relative paths and self-describing files over
  absolute paths or host-specific assumptions.
- **The artifacts are the interface.** The layout and conventions of the files are what must
  stay stable.

## How to Behave

1. When a step doesn't need my input, keep going. Put status notes in the same message as your next action.
Stop and ask only when you can't continue without me, or before anything destructive: deleting data, force-pushing, or changing anything outside this repository.

2. Once you have answered something, treat that answer as done. Focus on what I'm asking now, and don't go back over an earlier answer unless I ask about it or point out a problem with it.

## Project Structure

- `.claude-plugin/marketplace.json` — the `stella-agentic` plugin marketplace, listing every
  plugin under `plugins/`; `.claude/settings.json` enables them in this repo. Plugin and
  marketplace names must be kebab-case (no dots); the dotted form goes in `displayName`.
- `plugins/<name>/` — one plugin each; read its `README.md` before changing it.
  - `stella-agentic-workflow-docs` — the `docs/` structure: hooks, injected context, the
    `templates/docs/` scaffold, and the `docs-init`, `docs-doctor`, `docs-gc` skills.
- `docs/` — this repo's own instance of that structure.

## Conventions

- `templates/docs/` is the scaffold's source of truth; `init-docs.sh` only copies it,
  idempotently and without overwriting. Edit the templates, not the script.
- This repo's `docs/` scaffold (folder `README.md` prose and every `*.template.md`) must match
  `templates/docs/` byte-for-byte, so change both together. Records (`<PREFIX>-NNNN-slug.md`
  and their index lines) live only in `docs/`.
- `context/docs-structure.md` is injected into every session of every consuming repo: keep it a
  thin pointer. Record conventions belong in the folder `README.md`s.

## Tests

`bash scripts/checks.sh` runs every check (JSON validity, shellcheck, bootstrap idempotency,
hook behaviour, doctor, scaffold diff, context word budget). CI runs it on pushes to `main` and
on pull requests.
