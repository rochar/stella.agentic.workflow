## Agentic documentation structure (stella.agentic.workflow.docs)

This repository uses a standard `docs/` layout for knowledge that agents leave behind between
sessions. Read the relevant index before starting work, and record anything durable you produce
or discover.

```
docs/
├── README.md          # entry point, links to the four indexes below
├── adrs/              # architectural & design decision records
├── plans/             # plans produced by agents, skills, or workflows
├── memories/          # durable facts agents learned about this repository
└── learnings/         # lessons learned: failures, gotchas, corrections
```

Each folder has a `README.md` that is the **index** of its contents. The index is the interface:
whenever you add, rename, or remove a document, update that folder's `README.md` in the same change.

When to write each type:

- **docs/adrs/** — record any architectural or design decision that matters to new or existing
  features: technology choices, conventions adopted, trade-offs accepted, approaches rejected and
  why. Write one when a decision is made, not after the fact.
- **docs/plans/** — store every plan produced by an agent, skill, or workflow (implementation
  plans, migration plans, roadmaps) before executing it. Update the plan's status as work
  progresses.
- **docs/memories/** — save durable facts about the repository or its domain that are NOT
  derivable from the code or git history: environment quirks, external-system behavior, domain
  rules, owner/contact knowledge. Add a memory when you learn something a future session would
  otherwise have to rediscover.
- **docs/learnings/** — record lessons learned: an approach that failed and why, a user
  correction, a gotcha that cost time, a post-mortem. Add one whenever something did not work as
  expected and the reason is worth knowing next time.

File naming and record layout:

- A record is `NNNN-slug`: a zero-padded per-folder sequence (first record `0001`; take the
  next number from the folder's index) plus a kebab-case slug of at most 4 words (noun-phrase
  for ADRs, verb-phrase for plans). No dates in filenames — the date lives in the index line
  and the document header.
- ADRs and plans are **directories** of fixed-name part files, so agents load only the part
  they need: `adrs/NNNN-slug/` has `problem.md`, `decision.md`, `log.md`; `plans/NNNN-slug/`
  has `problem.md`, `plan.md` (carries the status). Keep `plan.md` and `decision.md` thin —
  execution steps/verification and decision/consequences respectively; investigation, root
  cause, forces, and alternatives go in `problem.md`, and ADR history is one dated line per
  event appended to `log.md`. Start a part file by copying its `<part>.template.md` from the
  folder (template files are not records and are never indexed).
- Memories and learnings are single files `NNNN-slug.md`, started from the folder's
  `memory.template.md` / `learning.template.md`; lead with the payload (fact / lesson), detail
  under it (see the folder README before splitting one).
- Index line, one per record: `- NNNN-slug — status — YYYY-MM-DD — one-line summary` (status
  only for ADRs and plans; update it whenever a record's status changes). Answer "is there a
  decision or plan about X?" from the index; open record files only when the index is not
  enough, and read parts shallow-to-deep: `plan.md` (or `decision.md`) first, `problem.md`
  only when you need the why or the investigation. Links point downward only — never link a
  docs file upward to `docs/README.md` or CLAUDE.md; that context is already loaded.

Rules for agents:

1. At the start of a task, skim `docs/README.md` and the indexes relevant to your task.
2. Before making a significant design decision, check `docs/adrs/` for prior decisions; do not
   silently contradict an accepted ADR.
3. When you finish work that produced a decision, plan, durable fact, or lesson, write it to the
   matching folder and add a one-line entry to that folder's `README.md` index.
4. Keep documents concise and self-contained. Start every document from its
   `<part>.template.md` in the folder (see that folder's `README.md`).
