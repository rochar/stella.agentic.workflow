---
id: ADR-0001
status: accepted # proposed | accepted | rejected | superseded
date: 2026-09-30
superseded-by:
scope: plugins/stella-agentic-workflow-docs/templates/docs, docs
summary: Every record is one prefixed file with YAML front matter; ADRs keep only Context and Decision
---
## Context
ADRs were directories of three part files (problem, decision, log), and specs and plans were
directories holding one file. Records are short, so the split cost more files and reads than
it saved. Agents need to judge relevance without reading bodies. Nygard ADRs are one file of
context, decision, consequences; MADR adds YAML front matter; Y-statements fit a decision in
one line. Rejected: keeping part files (overhead for short records); a log section (git
history already holds earlier states); prefix-only renames (no cheap skim).

## Decision
Every record is a single file `<PREFIX>-NNNN-slug.md` with prefixes `ADR`, `SPEC`, `PLAN`,
`MEM`, `LRN`. Each starts with YAML front matter holding its id, status or type, dates, and a
one-line `summary`. ADRs have only `## Context` and `## Decision` (ending in a `Binds:` line);
supersession is recorded in front matter (`status: superseded`, `superseded-by:`).

Binds: templates, folder READMEs, doctor-docs.sh, and skills treat records this way; the
doctor flags the pre-0.3.0 directory layout and unprefixed names for migration.
