---
id: ADR-20261003-dated-record-ids
status: accepted # proposed | accepted | rejected | superseded
date: 2026-10-03
superseded-by:
scope: plugins/stella-agentic-workflow-docs/templates/docs, docs
summary: Records are named by creation date, not sequence number; the full file stem is the id
---
## Context
Per-folder sequence numbers (`ADR-0007`) collide whenever parallel branches or sessions each
take the next free number, and the doctor then had to renumber one record and every reference
to it. Rejected: date only (two records of a type on one day collide); date and time (longer,
and migrated records would get invented times); random or hash ids (unreadable, not sortable).

## Decision
Name every record `<PREFIX>-YYYYMMDD-slug.md`, where the date is the record's creation date
and equals its `date:` field. The whole stem is the record's id: `id:`, `superseded-by:`, a
plan's `spec:` / `adrs:`, and prose all use it. Index lines drop their date column and stay
ordered by id. The doctor reports sequence-numbered records as `NUMBERED_ID` for migration.

Binds: templates, folder READMEs, doctor-docs.sh, and skills; ids are never re-dated or reused.
