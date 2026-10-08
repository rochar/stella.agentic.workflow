# stella.agentic.workflow

Claude Code plugins that give every AI agent in your repositories a shared, durable memory —
committed to the repository, owned by the team, and the same in every repo.

## Quickstart

1. **Install the plugin** — every collaborator runs this once, from the repository folder:

   ```
   claude plugin marketplace add rochar/stella.agentic.workflow
   claude plugin install stella-agentic-workflow-docs@stella-agentic --scope project
   ```

2. **Enable it for the repository** — add this to the repository's `.claude/settings.json`:

   ```json
   {
     "extraKnownMarketplaces": {
       "stella-agentic": {
         "source": { "source": "github", "repo": "rochar/stella.agentic.workflow" }
       }
     },
     "enabledPlugins": {
       "stella-agentic-workflow-docs@stella-agentic": true
     }
   }
   ```

3. **Bootstrap** the structure in a new Claude Code session (or run `/reload-plugins` in an
   open one):

   ```
   /stella-agentic-workflow-docs:docs-init
   ```

4. **Commit** `.claude/settings.json` and the new `docs/` folder.

Steps 2–4 are done once per repository; every collaborator still runs step 1 on their own
machine.

## What you get

```
docs/
├── README.md    # entry point, links to every index
├── adrs/        # decisions — written at decision time
├── specs/       # what to build and why
├── plans/       # how to build it — updated as work progresses
├── memories/    # durable facts a future session would otherwise rediscover
└── learnings/   # failed approaches, gotchas, corrections
```

Every session with the plugin installed starts knowing this structure and when to write each
record, and is reminded once per session to record anything durable it produced. You don't
have to prompt for it.

It is plain Markdown in **your** repository: reviewable in pull requests, and yours even if you
remove the plugin. Each folder's `README.md` indexes its records and explains the conventions.

## Commands

| Run | When |
| --- | --- |
| `/stella-agentic-workflow-docs:docs-init` | Once, to create `docs/`. Safe to re-run; never overwrites. |
| `/stella-agentic-workflow-docs:docs-doctor` | After a plugin update, when records stray from the conventions, or to adopt docs you already keep another way. |
| `/stella-agentic-workflow-docs:docs-gc` | Occasionally, to retire stale records and merge duplicates. |
| `/stella-agentic-workflow-docs:docs-spec` | To write a spec (what to build and why), refine it, or mark it approved, implemented, or abandoned. |

`docs-doctor`, `docs-gc`, and `docs-spec` never commit — review the diff like any other change.

## Why not just built-in memory or `CLAUDE.md`?

- **Built-in auto memory** is personal: it stays on one machine and never reaches teammates.
- **`CLAUDE.md`** is shared but freeform and maintained by hand, separately in each repository.
- **This framework** is shared, structured (typed records with templates and indexes), and
  defined once, in the plugin, for every repository that installs it.

## Plugins

| Plugin | What it does | Details |
| --- | --- | --- |
| `stella-agentic-workflow-docs` | The `docs/` structure, its session hooks, and the `docs-*` commands | [README](plugins/stella-agentic-workflow-docs/README.md) · [visual map](stella-agentic-workflow-docs.md) |

## Contributing

To change the framework itself, start with [CLAUDE.md](CLAUDE.md). This repository's own
[docs/](docs/README.md) is a live instance of the structure it ships.
