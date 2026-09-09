## Agentic docs (stella.agentic.workflow.docs)

This repository keeps knowledge agents leave behind in `docs/` — `adrs/` (architectural &
design decisions), `plans/` (plans produced by agents, skills, or workflows), `memories/`
(durable facts not derivable from code or git history), `learnings/` (failures, gotchas,
corrections). Each folder's `README.md` is the index of its contents.

1. Skim the indexes relevant to your task before starting; never silently contradict an
   accepted ADR. Index lines carry status: records whose status marks them no longer current
   are history, not guidance (each folder's `README.md` defines its statuses).
2. When your work produces a decision, plan, durable fact, or lesson, record it in the
   matching folder and update that folder's index in the same change.
3. Before writing or editing any record, read that folder's `README.md` — it defines naming,
   part files, templates, and the index-line format.
4. Load lazily: answer "is there a decision or plan about X?" from the index line alone, and
   open a record's parts shallow-to-deep — the folder `README.md` says which part holds what.
