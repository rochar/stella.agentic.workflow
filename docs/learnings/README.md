# Learnings

Lessons learned: approaches that failed and why, user corrections, gotchas that cost time,
post-mortems.

**When to add one:** whenever something did not work as expected and the reason is worth
knowing next time — but only if every rule below holds:

- It **cost real time** or produced a wrong result, and could plausibly recur.
- The lesson is **actionable** — what to do or avoid next time, not just "X happened".
- It is **not prevented by the fix itself** — an ordinary bug fixed in code needs no learning;
  record one only when the fix does not stop the mistake from being repeated elsewhere.
- It **duplicates no existing learning** — extend the existing record instead of adding a
  near-copy.

**Obsolescence:** a learning records something that happened, so it is never re-verified — but
its lesson can stop applying (the gotcha is fixed upstream, or a guard now prevents the mistake
structurally). When that happens, mark the record obsolete in place: set its front matter's
`obsolete: YYYY-MM-DD — <why it no longer applies>` and keep the rest as history. Its index line stays, suffixed `— obsolete`, so numbers are never reused and references
by number stay valid. Obsolete learnings are history, not guidance — skip them when skimming the
index.

**Naming:** each learning is one file `LRN-NNNN-slug.md` (zero-padded per-folder sequence;
kebab-case slug, at most 4 words — e.g. `LRN-0005-hook-stdout-buffering.md`). Take the next
number from the index below (first record: `LRN-0001`). A lesson that outgrows one file is
split into new numbered records.

**Reading:** the front matter's `summary` states the lesson; skip records with `obsolete:` set;
open the body for what happened.

**Template:** copy [`learning.template.md`](./learning.template.md) from this folder — lead
with the lesson, keep the story under it. Template files are not records — never list them in
the index.

**Index line:** `- LRN-NNNN-slug — YYYY-MM-DD — one-line summary` — keep the whole line at most
120 characters.

## Index

_No learnings yet._
