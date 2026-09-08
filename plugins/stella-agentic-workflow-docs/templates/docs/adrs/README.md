# Architectural Decision Records (ADRs)

Records of architectural and design decisions: technology choices, conventions adopted,
trade-offs accepted, and approaches rejected (with reasons). Anything important for new and
existing features belongs here.

**When to add one:** whenever an architectural or design decision is made — at decision time,
not retroactively.

**Naming:** each ADR is a directory `NNNN-slug/` (zero-padded per-folder sequence; kebab-case
noun-phrase slug, at most 4 words — e.g. `0012-use-postgres/`) containing `problem.md` (context
and forces), `decision.md` (the decision itself), and `log.md` (append-only: status changes,
revisits, outcomes). Take the next number from the index below (first record: `0001`).

**Split rule:** keep `decision.md` thin — the decision, its status, and its consequences (what
future work must respect). Rationale, forces, and options considered (including rejected ones)
belong in `problem.md`. History never accumulates in `decision.md`: status changes, revisits,
and outcomes are one dated line each, appended to `log.md`.

**Templates:** copy [`problem.template.md`](./problem.template.md),
[`decision.template.md`](./decision.template.md) and [`log.template.md`](./log.template.md)
from this folder. Template files are not records — never list them in the index.

**Reading:** shallow-to-deep and lazy — index line first, then `decision.md`, then
`problem.md` or `log.md` only when you need the why or the history. Parts sit side by side in
the record folder; no links between them are needed, and docs files never link upward (to
`docs/README.md` or CLAUDE.md).

**Index line:** `- NNNN-slug — status — YYYY-MM-DD — one-line summary` — keep the status
current here whenever it changes.

## Index

_No ADRs yet._
