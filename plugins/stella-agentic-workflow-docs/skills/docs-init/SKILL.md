---
name: docs-init
description: Bootstrap the standard agentic docs/ structure (adrs, plans, memories, learnings) with README index files in the current repository. Use when the docs/ structure is missing or incomplete.
---

Bootstrap the standard agentic documentation structure in the current repository.

Run the bundled idempotent script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-docs.sh"
```

The script creates `docs/` with `adrs/`, `plans/`, `memories/`, and `learnings/` subfolders,
each containing a `README.md` index and the document templates (`*.template.md`), plus a root
`docs/README.md` that links to the four indexes. It only creates what is missing and never
overwrites existing files, so it is safe to run in a repository that already has a `docs/`
folder (re-running it also backfills templates missing from an older bootstrap).

After running it:

1. Report which files were created (the script prints them).
2. If the repository has a CLAUDE.md, suggest referencing `docs/README.md` from it so the
   structure is also discoverable without the plugin.
3. Remind the user to commit the new files so the structure is shared with the team and with
   cloud sessions.
