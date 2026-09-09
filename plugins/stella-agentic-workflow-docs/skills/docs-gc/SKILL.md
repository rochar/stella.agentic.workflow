---
name: docs-gc
description: Garden the agentic docs/ tree (adrs, plans, memories, learnings) - fix index drift, re-verify or retire stale memories, mark obsolete learnings, merge near-duplicates, and tighten record prose, all without erasing history. Use when asked to review, clean up, or garden the docs/ records.
---

Garden the agentic `docs/` tree: keep it trustworthy and cheap to skim. This is a gardening
pass, not a purge — the conventions deliberately keep history (stable record numbers, index
lines that never disappear), so nothing in this skill erases the past.

Before touching anything:

1. If `docs/` is missing or not fully bootstrapped (any file of the plugin's `templates/docs/`
   scaffold absent — folder `README.md` indexes or `*.template.md` templates — the same
   definition the hooks use), stop and suggest running the `docs-init` skill instead.
2. Read each folder's `README.md` — they are the source of truth for naming, statuses,
   index-line formats, and retirement rules. Where a folder README and this skill disagree,
   the folder README wins.

Then work folder by folder (`adrs/`, `plans/`, `memories/`, `learnings/`):

## 1. Index integrity

- Every record has exactly one index line and every index line points to an existing record.
  The one allowed exception is a memory line suffixed `— deleted`, whose file is gone by
  design; an `— obsolete` learning keeps its file, so an `— obsolete` line with no file behind
  it is drift to flag.
- Index lines follow the folder's format; the status or type in the line matches the record
  body; template files (`*.template.md`) are never indexed.
- Fix mechanical drift like this directly.

## 2. Memories — staleness

- For each memory whose `## Verify` section describes a safe, read-only check (inspect a file,
  run a command with no side effects), run it. Confirmed → update `Verified:` to today. Wrong →
  correct the fact in place; if the correction is itself a lesson, record it in `learnings/`.
- A memory that cannot be checked safely: report it with its `Verified:` age; do not guess.
- A memory no longer relevant at all: delete the file, keep its index line suffixed
  `— deleted`.

## 3. Learnings — obsolescence

- A learning is never re-verified (it records a past event), but its lesson can stop applying —
  the gotcha fixed upstream, or a guard now prevents the mistake structurally. When the repo
  shows such evidence, mark the record obsolete in place as the folder README's Obsolescence
  rule defines (a dated `Obsolete:` line under the date line, story kept as history) and suffix
  its index line `— obsolete`.
- No clear evidence → report the suspicion, change nothing.

## 4. Duplicates

- Near-duplicate memories or learnings: merge the content into the older record, then retire
  the newer one per its folder's rule (memories: delete + `— deleted`; learnings: obsolete
  with a why that points at the kept record, e.g. `merged into 0003-…`).

## 5. ADRs and plans — status hygiene

- A plan whose work is demonstrably finished or abandoned (check git history) but still marked
  `proposed`/`in-progress`: update the status in `plan.md` and its index line.
- ADR statuses change only with evidence, recorded as a dated line in the record's `log.md`.
  Superseding an ADR requires writing a new one — out of scope here; report it instead.
- Never delete or rewrite ADR or plan records; they are kept history even when dead.

## 6. Prose

- Tighten one-line summaries in indexes, keep memories to one self-contained fact (split a
  record that grew a second fact into a new numbered record), make learnings lead with the
  lesson. Simplify wording only — never change what a record means.

## Boundaries

- Folder `README.md`s and `*.template.md` files are scaffold, not records — never edit them in
  this pass; put suggested convention changes in the report instead. (In the framework
  repository itself the scaffold must additionally stay in sync with `templates/docs/`:
  `*.template.md` byte-for-byte, README prose identical with added index lines as the only
  divergence.)
- Never renumber records or reuse a number; only memory files may be deleted, and every
  retired record keeps its index line.
- When unsure whether something is stale, obsolete, or duplicate: flag it in the report and
  leave it unchanged.

## Report

Finish with a summary: per folder, what was changed, what was flagged for a human to decide,
and what was checked and left alone. Do not commit — the diff is the deliverable; these docs
are team-shared and meant to be reviewed like any other change.
