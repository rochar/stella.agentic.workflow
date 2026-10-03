# Plans

Plans produced by agents, skills, or workflows: implementation plans, migration plans,
roadmaps. A plan defines how something will be done; what is being solved and why belongs in
a spec (`specs/`), not here.

**When to add one:** whenever an agent or skill produces a plan worth keeping.

**Status:** `proposed | in-progress | done | abandoned`, kept current in both the front matter
and the index line below. A plan exists to fulfil one request: once `done` or `abandoned` it is
history, never guidance — do not resume or follow it. Anything durable a plan produced or
discovered outlives it as an ADR, memory, or learning, not as the plan itself.

**Naming:** each plan is one file `PLAN-NNNN-slug.md` (zero-padded per-folder sequence;
kebab-case verb-phrase slug, at most 4 words — e.g. `PLAN-0007-migrate-auth.md`). Take the next
number from the index below (first record: `PLAN-0001`). A plan names the spec it implements
in its `spec:` field (`SPEC-NNNN-slug`), and the accepted ADRs it relies on in its `adrs:`
field (`ADR-NNNN-slug`, comma-separated) — each `none` when there are none.

**Split rule:** a plan holds the how — approach, steps, risks, verification. Requirements and
acceptance criteria belong in the spec; a decision that outlives the plan belongs in a new ADR,
added to `adrs:`. Steps are checkboxes, ticked as they are completed; long plans group them
into phases, each ending in a checkpoint.

**Reading:** start with the index line, then the front matter; open the body for the approach
and steps, the spec named in `spec:` for what is being solved, and follow only the ADRs in
`adrs:` that are still accepted.

**Template:** copy [`plan.template.md`](./plan.template.md) from this folder. Template files
are not records — never list them in the index.

**Index line:** `- PLAN-NNNN-slug — status — YYYY-MM-DD — one-line summary` — keep the status
current here whenever it changes, and keep the whole line at most 120 characters.

## Index

- PLAN-0001-add-dev-workflow-plugin — proposed — 2026-09-30 — Dev-workflow plugin skeleton with its dependencies
