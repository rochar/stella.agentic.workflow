# stella.agentic.workflow

Give every AI agent working in your repositories a shared, durable memory — owned by the team,
not by one machine. This framework installs a standard `docs/` structure — decisions, plans,
memories, learnings — into your repository and teaches it to every Claude Code session
automatically, so agents leave knowledge behind instead of rediscovering it, across sessions,
collaborators, and repositories.

## What you get

After installing and bootstrapping, your repository contains:

```
docs/
├── README.md          # entry point, links to the indexes below
├── adrs/              # architectural & design decision records
├── plans/             # plans produced by agents, skills, or workflows
├── memories/          # durable facts agents learned about the repository
└── learnings/         # lessons learned: failures, gotchas, corrections
```

Each folder has a `README.md` index of its contents and ships the templates new documents start
from. From then on, every Claude Code session — terminal CLI, desktop app, or cloud
(claude.ai/code) — starts already knowing where each document type lives, when to write one,
and that folder indexes must be kept up to date. You don't have to prompt for any of it.

The structure is plain Markdown committed to **your** repository: readable without any tooling,
reviewable in pull requests, and yours even if you later remove the plugin.

## How this differs from built-in memory

Claude Code's built-in auto memory is personal: it lives on one developer's machine, is never
committed, and doesn't reach teammates or cloud sessions. A project `CLAUDE.md` is team-shared
but freeform, hand-maintained, and per-repository. This framework covers the space between the
two:

- **Team-shared** — the knowledge is committed to the repository and reviewed in pull requests
  like any other change, so every collaborator's sessions benefit from what one session learned.
- **Consistent across repositories** — the convention is defined once in the plugin; every
  repository that installs it gets the same structure, and updates to the convention reach all
  of them without copy-pasting between `CLAUDE.md` files.
- **Structured** — typed records (decisions, plans, memories, learnings) with templates and
  per-folder indexes, instead of freeform notes.

## Installation

The framework is delivered as a Claude Code plugin (`stella-agentic-workflow-docs`) from the
`stella-agentic` marketplace hosted in this repository.

### Option A — recommended: check the configuration into your repository

Add this to your repository's `.claude/settings.json` (create the file if needed) and commit
it:

```json
{
  "extraKnownMarketplaces": {
    "stella-agentic": {
      "source": {
        "source": "github",
        "repo": "rochar/stella.agentic.workflow"
      }
    }
  },
  "enabledPlugins": {
    "stella-agentic-workflow-docs@stella-agentic": true
  }
}
```

What this gives you:

- Every collaborator who trusts the repository folder gets the `stella-agentic` marketplace
  registered automatically, with no extra prompt.
- The plugin is declared enabled for the project, which is also how **cloud sessions**
  (claude.ai/code) pick it up.
- Because the plugin comes from an external source, Claude Code asks each user to confirm the
  install once (it shows the `claude plugin install` command to run). After that one-time
  confirmation, the plugin is active in every session.

### Option B — manual, per user

Run these inside a Claude Code session in your repository:

```
/plugin marketplace add rochar/stella.agentic.workflow
/plugin install stella-agentic-workflow-docs@stella-agentic
```

Choose **project scope** during install to share the configuration with collaborators (this
writes the same settings as Option A).

### Bootstrap the structure

With the plugin installed, create the `docs/` tree once and commit the result:

```
/stella-agentic-workflow-docs:docs-init
```

The bootstrap is idempotent and never overwrites existing files, so it is safe to run in a
repository that already has a `docs/` folder — it only fills in what is missing.

## How it works

The plugin's `SessionStart` hook injects a short description of the structure into the context
of every session, pointing at the folder `README.md`s for the detailed conventions (naming,
templates, index format). If the `docs/` structure is missing, the hook tells the agent how to
bootstrap it instead. A `Stop` hook closes the loop on the write side: once per session — at
the first natural stopping point, since no hook can know which stop is the last — it asks
whether the session produced anything durable worth recording, and tells the agent to finish
without inventing records when nothing qualifies.

Because the bootstrapped `docs/` tree and its README files are committed to your repository,
the knowledge itself never depends on the plugin being installed — the plugin defines, teaches,
and bootstraps the convention; your repository owns the data.

## What agents write, and where

| Folder | What goes there | When |
| --- | --- | --- |
| `docs/adrs/` | Architectural and design decision records | At decision time |
| `docs/plans/` | Plans from agents, skills, or workflows | Before execution, updated as work progresses |
| `docs/memories/` | Durable facts not derivable from code or git history | Whenever a session learns something a future session would otherwise rediscover |
| `docs/learnings/` | Failed approaches, corrections, gotchas, post-mortems | Whenever something didn't work as expected |

Records are numbered per folder (`0001-slug`, `0002-slug`, …) and listed in that folder's
`README.md` index. The full conventions — part files, templates, index-line format — are
documented in the folder `README.md`s bootstrapped into your repository, and in the
[plugin README](plugins/stella-agentic-workflow-docs/README.md).

## Developing the framework

If you want to change the framework itself rather than consume it, start with
[CLAUDE.md](CLAUDE.md) (layout, conventions to preserve, how to test changes) and the
[plugin README](plugins/stella-agentic-workflow-docs/README.md). This repository's own
[docs/](docs/README.md) tree is a live instance of the structure it ships.
