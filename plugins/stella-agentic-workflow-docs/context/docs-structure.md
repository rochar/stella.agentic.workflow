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

File naming: ADRs are `NNNN-short-title.md` (zero-padded sequence); plans, memories, and
learnings are `YYYY-MM-DD-short-title.md`.

Rules for agents:

1. At the start of a task, skim `docs/README.md` and the indexes relevant to your task.
2. Before making a significant design decision, check `docs/adrs/` for prior decisions; do not
   silently contradict an accepted ADR.
3. When you finish work that produced a decision, plan, durable fact, or lesson, write it to the
   matching folder and add a one-line entry to that folder's `README.md` index.
4. Keep documents concise and self-contained. Document templates will be defined later; until
   then, use plain markdown with a clear title and date.
