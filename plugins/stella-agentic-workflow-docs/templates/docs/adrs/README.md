# Architectural Decision Records (ADRs)

Records of architectural and design decisions: technology choices, conventions adopted,
trade-offs accepted, and approaches rejected (with reasons). Anything important for new and
existing features belongs here.

**When to add one:** whenever an architectural or design decision is made — at decision time,
not retroactively.

**Naming:** each ADR is one file `ADR-NNNN-slug.md` (zero-padded per-folder sequence; kebab-case
noun-phrase slug, at most 4 words — e.g. `ADR-0012-use-postgres.md`). Take the next number from
the index below (first record: `ADR-0001`). Refer to an ADR elsewhere as `ADR-NNNN-slug`.

**Front matter:** `id`, `status`, `date`, `superseded-by`, `scope` (paths or areas it binds),
and `summary` (the decision in one line). It is written to be enough on its own: read the body
only when the ADR is `accepted` and its `scope` touches your task.

**Status:** `proposed | accepted | rejected | superseded`, kept current in both the front matter
and the index line below. Only **accepted** ADRs bind future work. `rejected` and `superseded`
records are history: never follow them, and never delete them. To supersede an ADR, write a new
one whose `## Context` says why, then set the old one's `status: superseded` and
`superseded-by: ADR-NNNN`. Git history keeps earlier states; there is no log section.

**Body:** `## Context` holds the forces, constraints, and rejected options (one line each, with
why). `## Decision` holds the decision in a few imperative sentences and a `Binds:` line — what
future work must respect. Keep both short.

**Template:** copy [`adr.template.md`](./adr.template.md) from this folder. Template files are
not records — never list them in the index.

**Index line:** `- ADR-NNNN-slug — status — YYYY-MM-DD — one-line summary` — keep the status
current here whenever it changes, and keep the whole line at most 120 characters.

## Index

_No ADRs yet._
