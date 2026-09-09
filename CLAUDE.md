# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

`stella.agentic.workflow` is a common framework for managing agentic workflows across
repositories: documentation structure, architectural decisions, memories, plugins, hooks, and
workflow state, so AI agents behave consistently across sessions and across projects.

Two consequences of that goal shape most decisions here:

- **This repo is consumed by other repos.** Anything added should be usable from a project that
  vendors, submodules, or installs this framework — prefer relative paths and self-describing
  files over absolute paths or host-specific assumptions.
- **The artifacts are the interface.** The framework's value is in the layout and conventions of
  its files, so those conventions are the thing to keep stable.

## Layout

- `.claude-plugin/marketplace.json` — this repo is a Claude Code plugin marketplace
  (`stella-agentic`); `.claude/settings.json` registers it and enables the docs plugin here.
- `plugins/stella-agentic-workflow-docs/` — the docs-structure plugin: hooks (`hooks/hooks.json`
  with a SessionStart handler `hooks-handlers/session-start.sh` and a Stop handler
  `hooks-handlers/stop.sh`), injected context (`context/docs-structure.md`), bootstrap
  (`scripts/init-docs.sh` copying `templates/docs/`), and the `docs-init` (bootstrap) and
  `docs-gc` (gardening) skills. Details in its `README.md`.
- `docs/` — this repo's own instance of the structure (adrs, plans, memories, learnings).

Naming constraint: Claude Code requires kebab-case plugin and marketplace names (no dots), so
the plugin is `stella-agentic-workflow-docs` and the marketplace is `stella-agentic`. How
downstream repositories install the framework is documented in `README.md`.

## Conventions to preserve

- `scripts/init-docs.sh` must stay idempotent and must never overwrite existing files. The
  bootstrapped content lives in `templates/docs/` (the script only copies it); edit the
  templates, not the script.
- This repo's own `docs/` tree carries the same scaffold as `templates/docs/`: the folder
  `README.md` prose and every `*.template.md` must match byte-for-byte, so change both
  together. Records written here (`NNNN-slug` entries and their index lines) live in `docs/`
  only and are never copied back into `templates/docs/`.
- Each `docs/*/README.md` is the index of its folder; any change to a folder's contents
  updates its index in the same change.
- The SessionStart hook communicates by printing to stdout; whatever it prints is added to the
  session context. `context/docs-structure.md` is paid for in every session of every consuming
  repo: keep it a thin pointer. The folder `README.md`s are the source of truth for record
  conventions (naming, part files, templates, index-line format) and are loaded lazily —
  detail goes there, never back into the injected context.

## Testing changes

There is no build or test suite. `bash scripts/checks.sh` runs every check below in one go,
plus `shellcheck` on all shell scripts (skipped locally when shellcheck is not installed).
CI (`.github/workflows/ci.yml`) runs the same script on pushes to `main` and on pull
requests. The individual manual steps, if you need to run one in isolation:

- `bash plugins/stella-agentic-workflow-docs/scripts/init-docs.sh <dir>` (run twice; the second
  run must report nothing to do)
- `CLAUDE_PROJECT_DIR=<dir> CLAUDE_PLUGIN_ROOT=$PWD/plugins/stella-agentic-workflow-docs bash
  plugins/stella-agentic-workflow-docs/hooks-handlers/session-start.sh` (with and without a
  bootstrapped `<dir>/docs`)
- `echo '{"stop_hook_active": false}' | CLAUDE_PROJECT_DIR=<dir> bash
  plugins/stella-agentic-workflow-docs/hooks-handlers/stop.sh` (must emit a block decision only
  when `<dir>/docs` is fully bootstrapped; with `"stop_hook_active": true`, or with a
  `"session_id"` whose session was already nudged, it must print nothing)
- validate every JSON file parses (e.g. `jq empty <file>`)
- `diff -r docs plugins/stella-agentic-workflow-docs/templates/docs` (the scaffold must match:
  no differences in any `*.template.md` or in README prose. Once this repo records ADRs, plans,
  memories, or learnings of its own, the only expected differences are those record files and
  their index lines under `docs/`)
