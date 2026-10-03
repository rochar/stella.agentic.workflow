# Specs

Specifications of what is to be built and why: features, bug fixes, changes in behaviour. A
spec defines the problem and what "done" means; how it is implemented belongs in a plan
(`plans/`), not here.

**When to add one:** whenever a problem or requirement is worth writing down before it is
implemented.

**Status:** `draft | approved | implemented | abandoned`, kept current in both the front matter
and the index line below. `implemented` and `abandoned` specs are history, never guidance — the
code is the source of truth for implemented behaviour. Anything durable a spec settled
outlives it as an ADR, memory, or learning, not as the spec itself.

**Naming:** each spec is one file `SPEC-NNNN-slug.md` (zero-padded per-folder sequence;
kebab-case noun-phrase slug, at most 4 words — e.g. `SPEC-0004-bulk-export.md`). Take the next
number from the index below (first record: `SPEC-0001`). Plans refer to a spec by its
`SPEC-NNNN-slug`.

**Split rule:** a spec states the what and the why — objective, scope, requirements,
acceptance criteria. Design, root cause, and implementation steps belong in a plan.

**Reading:** start with the index line, then the front matter (`summary` says what is needed);
open the body for the full definition.

**Template:** copy [`spec.template.md`](./spec.template.md) from this folder. Template files
are not records — never list them in the index.

**Index line:** `- SPEC-NNNN-slug — status — YYYY-MM-DD — one-line summary` — keep the status
current here whenever it changes, and keep the whole line at most 120 characters.

## Index

_No specs yet._
