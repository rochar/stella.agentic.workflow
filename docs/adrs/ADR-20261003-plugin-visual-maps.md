---
id: ADR-20261003-plugin-visual-maps
status: accepted # proposed | accepted | rejected | superseded
date: 2026-10-03
superseded-by:
scope: plugins, root plugin map files, README.md, scripts/checks.sh
summary: Every plugin has a root Mermaid map named after it, updated with any change to the plugin
---
## Context
A plugin's behaviour is spread over its manifest, hooks, injected context, skills, scripts, and
scaffold; nothing showed how they fit together or how they change a session's context.
Rejected: a map inside each plugin folder (it would ship to every consumer's plugin cache and
is less visible from the repository root); prose only (relations and flows read poorly as text).

## Decision
Each plugin under `plugins/` has a `<plugin-name>.md` at the repository root with
Mermaid diagrams of its artifacts, session and context flow, and the files it manages. The
README's Plugins table links every map. Any change to a plugin's artifacts updates its map in
the same change; a new plugin ships its map with it. `scripts/checks.sh` fails when a map is
missing, unlinked, or omits a skill, hook handler, agent, or command the plugin ships.

Binds: plugin changes and new plugins; the root map file name equals the plugin name.
