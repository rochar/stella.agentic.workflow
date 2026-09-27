---
name: docs-doctor
description: Diagnose and repair a repository's agentic docs/ tree so it follows the stella-agentic-workflow-docs conventions, structure, and templates - refresh the scaffold after a plugin update, migrate records written in an older or ad-hoc layout, and adopt decisions, specs, plans, memories, and learnings kept elsewhere into the structure. Use when adding the plugin to a repository that already has docs, after updating the plugin, when records were written without following the structure, or whenever asked to check, validate, fix, upgrade, migrate, or reconcile docs/ - even if the user never says "doctor".
---

Bring the repository's `docs/` tree back in line with the plugin: its scaffold (folder
`README.md` indexes and `*.template.md` files), its record layout, and its index lines. Three
situations lead here, and the same pass handles all of them:

- **Adding the plugin** to a repository that already keeps decisions, plans, or notes in its
  own way — that knowledge should end up as proper records, not beside them.
- **Updating the plugin** — the scaffold changed (new folders, new template fields, a part
  file moved to another record type) and existing records follow the old shape.
- **Drift** — sessions wrote records without following the conventions.

This is a structural pass. Content gardening — stale memories, obsolete learnings, merging
near-duplicates, dead statuses — belongs to the `docs-gc` skill; suggest it at the end if you
notice such things, but do not do it here.

## 1. Diagnose and repair the scaffold

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor-docs.sh" --fix
```

The script compares `docs/` with the plugin's `templates/docs/` and, with `--fix`, repairs the
scaffold in place: creates missing folders, indexes, and templates; restores drifted
`*.template.md`; refreshes folder README prose while keeping their index lines; removes
templates the plugin no longer ships. It never touches records. What remains is one finding
per line — `[record] …` for records or index lines that break a convention, `[stray] …` for
content outside the structure — plus `README_MERGE` when the root `docs/README.md` has local
additions the script could not merge (merge them by hand into the new template).

Then read every folder `README.md` (now current). They are the source of truth for naming,
part files, statuses, split rules, and index-line formats; where they and this skill
disagree, they win. Also read the template of each record type you are about to write.

## 2. Reconcile records

Work through the `[record]` findings. The principle: **every fix is backed by evidence** — the
record's own content, other records, the code, or `git log` — and nothing a record says is
lost. Where no evidence exists, do not invent it: write `Not recorded.` in a required section
the content cannot fill, and list the gap in the report.

- **Content in the wrong place** (`EXTRA_PART`, `MISSING_PART`, `MISSING_SECTION`, or a
  record mixing what a split rule separates). Move content to where the folder README now
  puts it; restructure it under the template's headings. Moves, never deletions. Typical
  upgrade case: a plan with a `problem.md` from an older layout — the what/why and
  requirements become a new spec (next spec number; status `implemented` if the plan is
  `done`, `abandoned` if it was abandoned, otherwise `draft`), root cause and alternatives
  go to the plan's `## Approach`, and the plan's `Spec:` line names the new spec.
- **A record that belongs in another folder** (e.g. a plan record that only ever held a
  problem statement, or a memory that is really a learning). Re-create it in the right folder
  under that folder's next number. Keep the original as a pointer so its number is never
  reused and references stay valid, retired by its own folder's rule: plans and specs
  → a stub keeping the title and metadata lines, status `abandoned`, and one line saying where
  the content now lives (no template sections — the checker does not require them for
  `abandoned` records, so do not pad them with `Not recorded.`); memories →
  deleted file, index line suffixed `— deleted`; learnings → `Obsolete:` line pointing at the
  new record. ADRs are never retired this way — flag instead.
- **Layout and naming** (`WRONG_LAYOUT`, `BAD_NAME`, `SLUG_TOO_LONG`, `BAD_TITLE`). Keep the
  number; convert the layout (`git mv` so history follows), shorten or kebab-case the slug,
  fix the title line. Then search the repository for references to the old path or stem and
  update them.
- **Duplicate numbers** (`DUP_NUMBER`). The record created later (by `git log`) takes the
  folder's next free number; update its index line and any references.
- **Metadata** (`MISSING_FIELD`, `INVALID_VALUE`). Normalize values that clearly map to the
  vocabulary (`Accepted` → `accepted`, `owner` → `ownership`). Fill missing fields from
  evidence: `Date:` from the record or the file's first commit; a missing memory `Verified:`
  takes the `Date:` value (the last known confirmation — never today's date unless you
  actually verified the fact); a plan's `Spec:` / `ADRs:` name the records it clearly
  implements or relies on, else `none`. A value with no clear mapping: flag it.
- **Indexes** (`UNINDEXED`, `ORPHAN_INDEX`, `INDEX_MISMATCH`, `INDEX_FORMAT`, `DUP_INDEX`,
  `LINE_TOO_LONG`). Every record gets exactly one index line in the folder's format, ordered
  by number, at most 120 characters. For a mismatch the record body wins unless `git log`
  shows the index line was the later, deliberate change. For an orphan line, look for the
  record in `git log` (renamed → fix the line; a deleted memory → suffix `— deleted`); if
  nothing explains it, leave the line and flag it — the number stays taken either way.
- **`UNFILLED_PLACEHOLDER`**: remove optional sections that were never filled; fill required
  ones from evidence or `Not recorded.`.

Never renumber a record except to resolve a duplicate, never reuse a number, and never delete
an ADR, spec, or plan.

## 3. Adopt stray content

`[stray]` findings are knowledge outside the structure: files or folders in `docs/` that are
not part of it (`OUTSIDE_STRUCTURE`), unnumbered files inside a record folder (`UNNUMBERED`),
and likely candidates elsewhere in the repository (`CANDIDATE`, a name-based guess — also
look for decision logs, plans, or gotcha lists the heuristic missed, such as sections of a
top-level `NOTES.md`).

For each, read it and classify it against the folder READMEs' "When to add one" and
qualification rules:

- **It fits a record type** → write it as record(s) of the type(s) its content actually is —
  one record per thing the source records, not one per template that could relate to it. Do
  not create a record the source cannot fill: a plan with no stated requirements does not
  need a spec made up for it (its `Spec:` line is simply `none`), and a record whose required
  sections would mostly read `Not recorded.` is a sign it should not exist. Keep every fact and
  its original date (from the text or `git log`), status mapped to the vocabulary, numbered in
  the original's chronological order. One file may become several records (a gotchas list is
  often a learning plus a memory); content that fails a folder's qualification rules does not
  become a record — say so in the report. When a file maps 1:1 onto a record, `git mv` it
  first and then restructure, so history follows; when it is split, delete it only after all
  of its content has landed. Update links to the old path across the repository (READMEs,
  CLAUDE.md, AGENTS.md, other docs).
- **It is other documentation** (user guides, API references, runbooks, architecture
  overviews that record no decision) → leave it where it is. `docs/` may hold it; stray
  findings are advisory and never make the check fail.

## 4. Verify

Re-run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor-docs.sh"` until it reports conformance, or
until the only findings left are ones you flagged on purpose. Stray items you decided to leave
will still be listed; that is expected.

## Report

Finish with:

1. **Scaffold** — what the script repaired, noting any local README prose that was replaced.
2. **Migrations** — a table of old path → new record(s), for everything moved, split,
   renamed, or adopted.
3. **Fixed in place** — metadata, index, and layout fixes, grouped per folder.
4. **Flagged for a human** — every gap written as `Not recorded.`, unmapped values, orphan
   lines, ADRs that look superseded, and anything else you left unchanged on purpose, each
   with why.
5. **Left alone** — stray documentation kept as it is.

If the repository has a CLAUDE.md that does not reference `docs/README.md`, suggest adding it.
Do not commit: the diff is the deliverable, and these docs are team-shared, so a human should
review the reconciliation like any other change.
