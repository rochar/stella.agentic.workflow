# Plans

Plans produced by agents, skills, or workflows: implementation plans, migration plans,
roadmaps. A plan is stored here before it is executed and its status is updated as work
progresses.

**When to add one:** whenever an agent or skill produces a plan worth keeping.

**Naming:** each plan is a directory `NNNN-slug/` (zero-padded per-folder sequence; kebab-case
verb-phrase slug, at most 4 words — e.g. `0007-migrate-auth/`) containing `problem.md` (what is
being solved and why) and `plan.md` (the plan; carries the status, updated as work progresses).
Take the next number from the index below (first record: `0001`).

**Split rule:** keep `plan.md` thin — execution only (steps and verification). Everything
discovered while producing the plan (context, root cause, investigation, alternatives
considered) belongs in `problem.md`; if a step needs justification, the justification goes in
`problem.md`. A record may exist with only `problem.md` before a plan is written — index it
with status `proposed`.

**Templates:** copy [`problem.template.md`](./problem.template.md) and
[`plan.template.md`](./plan.template.md) from this folder. Template files are not records —
never list them in the index.

**Reading:** shallow-to-deep and lazy — index line first, then `plan.md`, then `problem.md`
only when you need the why. Parts sit side by side in the record folder; no links between
them are needed, and docs files never link upward (to `docs/README.md` or CLAUDE.md).

**Index line:** `- NNNN-slug — status — YYYY-MM-DD — one-line summary` — keep the status
current here whenever it changes.

## Index

_No plans yet._
