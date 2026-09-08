# stella.agentic.workflow

A common framework for managing agentic workflows across repositories. It organizes
documentation, architectural decisions, memories, learnings, and plans so that AI agents behave
consistently across sessions and across projects.

This repository is both the home of the framework's plugins and a **Claude Code plugin
marketplace** (`stella-agentic`, defined in [.claude-plugin/marketplace.json](.claude-plugin/marketplace.json)).

## Plugins

| Plugin | Purpose |
| --- | --- |
| [`stella-agentic-workflow-docs`](plugins/stella-agentic-workflow-docs/README.md) | Standard `docs/` structure (adrs, plans, memories, learnings) with README indexes, a SessionStart hook that teaches every session the conventions, and a bootstrap skill. |

> Claude Code requires kebab-case plugin names, so the plugin is named
> `stella-agentic-workflow-docs` (display name: `stella.agentic.workflow.docs`).

## Installing the docs plugin in a repository

### Option A — recommended: check the configuration into the target repository

Add this to the target repository's `.claude/settings.json` (create the file if needed) and
commit it:

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
  install, the SessionStart hook runs in every session.

Then, in the target repository, bootstrap the folder structure once and commit it:

```
/stella-agentic-workflow-docs:docs-init
```

### Option B — manual, per user

```
/plugin marketplace add rochar/stella.agentic.workflow
/plugin install stella-agentic-workflow-docs@stella-agentic
/stella-agentic-workflow-docs:docs-init
```

Choose **project scope** during install to share the configuration with collaborators (this
writes the same settings as Option A).

### How every session learns the structure

The plugin's `SessionStart` hook prints
[docs-structure.md](plugins/stella-agentic-workflow-docs/context/docs-structure.md) into the
session context at startup — in the terminal CLI, the desktop app, and cloud sessions alike. The
agent therefore always knows where each document type lives, when to write one, and that each
folder's `README.md` index must be updated alongside any change. If the `docs/` structure is
missing, the hook tells the agent how to bootstrap it.

Because the bootstrapped `docs/` tree and its README files are committed to each consuming
repository, the knowledge itself never depends on the plugin being installed — the plugin
defines, teaches, and bootstraps the convention; the repository owns the data.

## Documentation structure

This repository follows its own convention — see [docs/README.md](docs/README.md):

```
docs/
├── README.md          # entry point, links to the indexes below
├── adrs/              # architectural & design decision records
├── plans/             # plans produced by agents, skills, or workflows
├── memories/          # durable facts agents learned about the repository
└── learnings/         # lessons learned: failures, gotchas, corrections
```

Each folder ships standalone `*.template.md` files; every document starts as a copy of its template.
