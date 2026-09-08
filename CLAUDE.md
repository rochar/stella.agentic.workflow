# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

`stella.agentic.workflow` is intended to be a common framework for managing agentic workflows
across repositories. It organizes documentation, architectural decisions, memories, plugins,
hooks, and workflow state so that AI agents behave consistently across sessions and across
projects.

Two consequences of that goal shape most decisions here:

- **This repo is consumed by other repos.** Anything added should be usable from a project that
  vendors, submodules, or symlinks this framework — not just from inside this checkout. Prefer
  relative paths and self-describing files over absolute paths or host-specific assumptions.
- **The artifacts are the interface.** The framework's value is in the layout and conventions of
  its files (where a decision record lives, how a hook is registered, how workflow state is
  serialized), so those conventions are the thing to keep stable.

## Layout

```
.claude-plugin/marketplace.json   # this repo is a Claude Code plugin marketplace ("stella-agentic")
.claude/settings.json             # registers the marketplace + enables the docs plugin for this repo
plugins/
└── stella-agentic-workflow-docs/ # the docs-structure plugin (see its README.md)
    ├── .claude-plugin/plugin.json
    ├── hooks/hooks.json          # SessionStart hook registration
    ├── hooks-handlers/           # hook scripts (session-start.sh)
    ├── context/docs-structure.md # the conventions injected into every session
    ├── scripts/init-docs.sh      # idempotent bootstrap of the docs/ tree
    ├── templates/docs/           # source of truth for the bootstrapped tree (copied by init-docs.sh)
    └── skills/docs-init/SKILL.md # /stella-agentic-workflow-docs:docs-init
docs/                             # this repo's own instance of the structure
├── adrs/  plans/  memories/  learnings/   (each with a README.md index)
```

Naming constraint: Claude Code requires kebab-case plugin and marketplace names (no dots), so the
plugin is `stella-agentic-workflow-docs` (display name `stella.agentic.workflow.docs`) and the
marketplace is `stella-agentic`.

## How downstream repositories install the framework

A consuming repository checks in a `.claude/settings.json` with `extraKnownMarketplaces` pointing
at `rochar/stella.agentic.workflow` (github source) and
`"stella-agentic-workflow-docs@stella-agentic": true` under `enabledPlugins`, then runs
`/stella-agentic-workflow-docs:docs-init` once and commits the generated `docs/` tree. The exact
snippet and the manual `/plugin` alternative are in `README.md`.

## Conventions to preserve

- `scripts/init-docs.sh` must stay idempotent and must never overwrite existing files. The
  bootstrapped content lives in `templates/docs/` (the script only copies it); edit the
  templates, not the script, and keep this repo's own `docs/` tree in sync with them.
- The SessionStart hook communicates by printing to stdout; whatever it prints is added to the
  session context. Keep `context/docs-structure.md` compact — it is paid for in every session.
- Each `docs/*/README.md` is the index of its folder; any change to a folder's contents updates
  its index in the same change.
- Document templates for the four types are deliberately not defined yet. Do not add them
  speculatively.

## Testing changes

There is no build, linter, or test suite. To verify plugin changes by hand:

- `bash plugins/stella-agentic-workflow-docs/scripts/init-docs.sh <dir>` (run twice; the second
  run must report nothing to do)
- `CLAUDE_PROJECT_DIR=<dir> CLAUDE_PLUGIN_ROOT=$PWD/plugins/stella-agentic-workflow-docs bash
  plugins/stella-agentic-workflow-docs/hooks-handlers/session-start.sh` (with and without a
  bootstrapped `<dir>/docs`)
- validate every JSON file parses (e.g. `jq empty <file>`)
