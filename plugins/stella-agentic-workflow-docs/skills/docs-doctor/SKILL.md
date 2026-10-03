---
name: docs-doctor
description: Diagnose and repair a repository's agentic docs/ tree so it follows the stella-agentic-workflow-docs conventions, structure, and templates - refresh the scaffold after a plugin update, migrate records written in an older or ad-hoc layout, and adopt decisions, specs, plans, memories, and learnings kept elsewhere into the structure. Use when adding the plugin to a repository that already has docs, after updating the plugin, when records were written without following the structure, or whenever asked to check, validate, fix, upgrade, migrate, or reconcile docs/ - even if the user never says "doctor".
---

Bring the repository's `docs/` tree back in line with the plugin: its scaffold (folder
`README.md` indexes and `*.template.md` files), its record layout, and its index lines. Three
situations lead here, and the same pass handles all of them:

- **Adding the plugin** to a repository that already keeps decisions, plans, or notes in its
  own way — that knowledge should end up as proper records, not beside them.
- **Updating the plugin** — the scaffold changed (new folders, new template fields, a new
  record layout or naming) and existing records follow the old shape.
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
front matter, statuses, split rules, and index-line formats; where they and this skill
disagree, they win. Also read the template of each record type you are about to write.

## 2. Reconcile records

Work through the `[record]` findings. The principle: **every fix is backed by evidence** — the
record's own content, other records, the code, or `git log` — and nothing a record says is
lost. Where no evidence exists, do not invent it: write `Not recorded.` in a required section
the content cannot fill, and list the gap in the report.

- **Content in the wrong place** (`MISSING_SECTION`, or a record mixing what a split rule
  separates). Move content to where the folder README now puts it; restructure it under the
  template's headings. Moves, never deletions. Typical upgrade cases from the pre-0.3.0
  layout (`WRONG_LAYOUT` on a `NNNN-slug/` directory), each named by its `date:` as the
  `NUMBERED_ID` bullet below describes:
  - an ADR directory → one `ADR-YYYYMMDD-slug.md`: status and date from `decision.md` into
    front matter (a `superseded by NNNN` status becomes `status: superseded` plus
    `superseded-by:` that ADR's new id); `problem.md` context and options into `## Context`,
    options one line each; `decision.md` decision into `## Decision` and its consequences into the
    `Binds:` line. `log.md`: move each reason it records (why a status changed, what an
    amendment changed) into `## Context`, one line each; only then remove it — git history
    keeps its earlier states.
  - a spec or plan directory → its `spec.md` / `plan.md` becomes `SPEC-` /
    `PLAN-YYYYMMDD-slug.md`. A plan's old `problem.md`: the what/why and requirements become
    a new spec (dated like the plan; status `implemented` if the plan is `done`, `abandoned` if it was abandoned,
    otherwise `draft`), root cause and alternatives go to the plan's `## Approach`, and the
    plan's `spec:` field names the new spec.
  - a memory or learning directory (a record promoted to a directory before 0.3.0) → one
    `MEM-` / `LRN-YYYYMMDD-slug.md` for its first fact or lesson; each further fact or lesson
    becomes a new record with its own slug.
- **A record that belongs in another folder** (e.g. a plan record that only ever held a
  problem statement, or a memory that is really a learning). Re-create it in the right folder
  under that folder's prefix, keeping its date and slug. Keep the original as a pointer so its
  id is never reused and references stay valid, retired by its own folder's rule: plans and specs
  → a stub keeping the front matter, status `abandoned`, and one line saying where
  the content now lives (no template sections — the checker does not require them for
  `abandoned` records, so do not pad them with `Not recorded.`); memories →
  deleted file, index line suffixed `— deleted`; learnings → `obsolete:` field pointing at the
  new record. ADRs are never retired this way — flag instead.
- **Sequence-numbered records** (`NUMBERED_ID`, the pre-0.4.0 `<PREFIX>-NNNN-slug.md`
  naming). `git mv` the file to `<PREFIX>-YYYYMMDD-slug.md`, the date taken from its `date:`
  (else the file's first commit), and set `id:` to the new stem. If two records would get the
  same name, give the later one (by `git log`) a more specific slug. Then rewrite every
  reference to the old stem or bare `<PREFIX>-NNNN` across the repository — `superseded-by:`,
  `spec:`, `adrs:`, index lines, and prose — and drop the date column from its index line. A
  deleted memory survives only as its `— deleted` index line: rename the stem there using
  that line's own date column, then drop the column.
- **Layout and naming** (`WRONG_LAYOUT`, `BAD_NAME`, `SLUG_TOO_LONG`, `MISSING_FRONT_MATTER`).
  Convert the layout (`git mv` so history follows), name the file by its date as above, add the
  folder prefix, shorten or kebab-case the slug, convert a title and `- Key:` metadata lines
  into front matter. Then search the repository for references to the old path or stem (bare
  `NNNN-slug` included) and update them.
- **Metadata** (`MISSING_FIELD`, `INVALID_VALUE`). Normalize values that clearly map to the
  vocabulary (`Accepted` → `accepted`, `owner` → `ownership`). Fill missing fields from
  evidence: `date:` from the record or the file's first commit; a missing memory `verified:`
  takes the `date:` value (the last known confirmation — never today's date unless you
  actually verified the fact); a plan's `spec:` / `adrs:` name the records it clearly
  implements or relies on, else `none`; a missing `summary:` is the record's gist in one line,
  taken from its body; `id:` is the file stem; a `date:` that differs from the date in the
  file name is corrected to the name's date — the name is the id and is never re-dated —
  unless evidence shows the name's date is the wrong one (then flag it); an ADR's `scope:`
  names the paths or areas its decision text covers (`all` only when the text says so — an
  unclear scope is flagged, not guessed). A value that is not valid YAML unquoted (it contains
  `: ` or starts with a character such as `` ` `` or `[`) gets quotes. A value with no clear
  mapping: flag it.
- **Indexes** (`UNINDEXED`, `ORPHAN_INDEX`, `INDEX_MISMATCH`, `INDEX_FORMAT`, `DUP_INDEX`,
  `LINE_TOO_LONG`). Every record gets exactly one index line in the folder's format, ordered
  by id, at most 120 characters. For a mismatch the record body wins unless `git log`
  shows the index line was the later, deliberate change. For an orphan line, look for the
  record in `git log` (renamed → fix the line; a deleted memory → suffix `— deleted`); if
  nothing explains it, leave the line and flag it — the id stays taken either way.
- **`UNFILLED_PLACEHOLDER`**: remove optional sections that were never filled; fill required
  ones from evidence or `Not recorded.`.

Never re-date or rename a record except to migrate it to the current naming, never reuse an
id, and never delete an ADR, spec, or plan.

## 3. Adopt stray content

`[stray]` findings are knowledge outside the structure: files or folders in `docs/` that are
not part of it (`OUTSIDE_STRUCTURE`), undated files inside a record folder (`UNDATED`),
and likely candidates elsewhere in the repository (`CANDIDATE`, a name-based guess — also
look for decision logs, plans, or gotcha lists the heuristic missed, such as sections of a
top-level `NOTES.md`).

For each, read it and classify it against the folder READMEs' "When to add one" and
qualification rules:

- **It fits a record type** → write it as record(s) of the type(s) its content actually is —
  one record per thing the source records, not one per template that could relate to it. Do
  not create a record the source cannot fill: a plan with no stated requirements does not
  need a spec made up for it (its `spec:` field is simply `none`), and a record whose required
  sections would mostly read `Not recorded.` is a sign it should not exist. Keep every fact and
  its original date (from the text or `git log`), status mapped to the vocabulary, and named by
  that original date. One file may become several records (a gotchas list is
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
