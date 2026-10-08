---
name: docs-gc
description: Garden the content of the agentic docs/ records (adrs, specs, plans, memories, learnings) - re-verify or retire stale memories, mark obsolete learnings, merge near-duplicates, update dead spec and plan statuses, and tighten record prose, all without erasing history. Use when asked to review, clean up, or garden the docs/ records, or to check whether they are still accurate. For structure (layout, naming, templates, indexes, plugin upgrades) use docs-doctor instead.
---

Garden the agentic `docs/` records: keep what they say trustworthy and cheap to skim. This is
a gardening pass, not a purge — the conventions deliberately keep history (stable record
ids, index lines that never disappear), so nothing in this skill erases the past.

This skill is about content — whether records are still true, current, and distinct. Their
shape (scaffold, layout, naming, fields, index-line format) is the `docs-doctor` skill's job,
checked by the same script this skill starts with.

Before touching anything:

1. Run the structural check:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor-docs.sh"
   ```

   If it reports any `[scaffold]` or `[record]` finding (it exits non-zero), stop and suggest
   running the `docs-doctor` skill first — gardening records whose structure is off means
   guessing where things belong. `[stray]` items are advisory and do not block this pass.
2. Read each folder's `README.md` — they are the source of truth for naming, statuses,
   index-line formats, and retirement rules. Where a folder README and this skill disagree,
   the folder README wins.

Then work folder by folder (`adrs/`, `specs/`, `plans/`, `memories/`, `learnings/`). Every
change below that touches a status, a retirement suffix, or a summary updates the record and
its index line together.

## 1. Memories — staleness

- For each memory whose `## Verify` section describes a safe, read-only check (inspect a file,
  run a command with no side effects), run it. Confirmed → update `verified:` to today. Wrong →
  correct the fact in place; if the correction is itself a lesson, record it in `learnings/`.
- A memory that cannot be checked safely: report it with its `verified:` age; do not guess.
- A memory no longer relevant at all: delete the file, keep its index line suffixed
  `— deleted`.

## 2. Learnings — obsolescence

- A learning is never re-verified (it records a past event), but its lesson can stop applying —
  the gotcha fixed upstream, or a guard now prevents the mistake structurally. When the repo
  shows such evidence, mark the record obsolete in place as the folder README's Obsolescence
  rule defines (a dated `obsolete:` front-matter value, story kept as history) and suffix
  its index line `— obsolete`.
- No clear evidence → report the suspicion, change nothing.

## 3. Duplicates

- Near-duplicate memories or learnings: merge the content into the older record, then retire
  the newer one per its folder's rule (memories: delete + `— deleted`; learnings: obsolete
  with a why that points at the kept record, e.g. `merged into LRN-YYYYMMDD-slug`).

## 4. ADRs, specs, and plans — status hygiene

- An `approved` spec whose acceptance criteria demonstrably hold: set it `implemented`. A
  `draft` spec whose criteria hold was never approved: flag it in the report instead. A spec
  whose work was dropped (`draft` or `approved`): set it `abandoned`. Each change updates the
  front-matter `status` and the index line.
- A plan whose work is demonstrably finished or abandoned (check git history) but still marked
  `proposed`/`in-progress`: update the front-matter `status` and the index line.
- ADR statuses change only with evidence (front-matter `status`, and `superseded-by` when
  superseded).
  Superseding an ADR requires writing a new one — out of scope here; report it instead.
- Never delete or rewrite ADR, spec, or plan records; they are kept history even when dead.

## 5. Prose

- Tighten one-line summaries in indexes, keep memories to one self-contained fact (split a
  record that grew a second fact into a new record), make learnings lead with the
  lesson. Simplify wording only — never change what a record means.
- Enforce each folder's split rule: rationale or rejected options in an ADR's `## Decision` move to
  its `## Context` — move, never delete. A spec carrying design or
  steps, or a plan carrying requirements, spans two records: flag it in the report instead.

## Boundaries

- Folder `README.md`s and `*.template.md` files are scaffold, not records — never edit them in
  this pass; put suggested convention changes in the report instead. (In the framework
  repository itself the scaffold must additionally stay in sync with `templates/docs/`:
  `*.template.md` byte-for-byte, README prose identical with added index lines as the only
  divergence.)
- Never rename records or reuse an id; only memory files may be deleted, and every
  retired record keeps its index line.
- When unsure whether something is stale, obsolete, or duplicate: flag it in the report and
  leave it unchanged.

## Verify

Re-run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor-docs.sh"`: the pass must leave the tree as
structurally clean as it found it (retirements and merges included).

## Report

Finish with a summary: per folder, what was changed, what was flagged for a human to decide,
and what was checked and left alone. Do not commit — the diff is the deliverable; these docs
are team-shared and meant to be reviewed like any other change.
