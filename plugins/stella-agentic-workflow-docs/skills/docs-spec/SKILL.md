---
name: docs-spec
description: Create, refine, and manage the lifecycle of a spec record in the agentic docs/specs/ folder - draft a new SPEC-YYYYMMDD-slug.md from a feature request, bug report, or ticket; tighten its scope and acceptance criteria; and move it through draft, approved, implemented, or abandoned with its index line kept in sync. Use whenever the user asks to write, draft, update, approve, close, or abandon a spec, to capture requirements or acceptance criteria for a feature, bug, or change before implementing it, or to "spec out" a ticket - even if they do not say "spec". Not for implementation plans or design (those are plans and ADRs).
---

Author and maintain one spec record in `docs/specs/` so that it follows the folder's
conventions exactly. A spec states **what** is needed and **why** — objective, scope,
requirements, acceptance criteria — so that someone (human or agent) can later plan and
verify the work without re-asking. How it gets built belongs in a plan, never here.

This skill handles a single spec at a time and does not impose a workflow: it never decides
that a spec must exist before a plan, and it never approves a spec on its own. Workflows
built on the docs structure decide that; this skill only makes the record right.

## Before anything

1. If `docs/specs/README.md` does not exist, stop and suggest the `docs-init` skill.
2. Read `docs/specs/README.md`. It is the source of truth for naming, statuses, the split
   rule, and the index-line format; where it and this skill disagree, the README wins.
3. Pick the mode from the request: **Create** (new spec), **Refine** (change an existing
   spec's content), or **Transition** (change its status). A request can combine them
   (e.g. "tighten SPEC-… and approve it").

## Create

1. **Look for an existing spec first.** Scan the index in `docs/specs/README.md` for one on
   the same topic. If a live (`draft`/`approved`) spec covers it, offer to refine that one
   instead of creating a duplicate.
2. **Gather what makes the spec testable.** From the request, any linked ticket you can
   read, and the code, work out:
   - the objective — what is needed, why, and who benefits;
   - the scope — what is in, and explicit non-goals;
   - the `type` — `feature`, `bug`, or `change`; for a bug, observed versus expected
     behaviour (and how to reproduce it, if known);
   - acceptance criteria — specific conditions someone could check.

   Ask the user only about gaps that would leave the spec untestable or ambiguous in scope,
   in one batch of short questions. Do not ask about what you can read from the code or
   the ticket. If the user cannot or will not answer, write the spec anyway and put the gap
   under `## Open questions` — never invent requirements to fill it.
3. **Name it.** The id is `SPEC-YYYYMMDD-slug`: today's date and a kebab-case noun-phrase
   slug of at most 4 words (`bulk-export`, `sso-token-expiry-hang`). Check no file with
   that name exists. The file is `docs/specs/<id>.md`.
4. **Write it from the repository's own template**, `docs/specs/spec.template.md` (copy it;
   do not reconstruct it from memory — the repo's copy may be newer than this skill).
   - Front matter: `id` = the file stem, `status: draft`, `type`, `date` = today
     (`YYYY-MM-DD`), `source` = the ticket/issue link or `none`, `summary` = one line saying
     what is needed and why. Keep the template's `# vocabulary` comments. Quote a value that
     contains `: ` (e.g. `summary: "Export: add CSV"`) — unquoted it is invalid YAML.
   - `## Objective`: self-contained — a reader without tracker access must understand it.
     Restate the ticket; do not just link it.
   - `## Scope`: fill both `- In:` and `- Out:` lines (write `- Out: none` if there are no
     non-goals).
   - `## Requirements`: the behaviour to deliver. For a bug, observed versus expected.
   - `## Acceptance criteria`: unticked `- [ ]` items, each one observable and checkable
     ("export of 10k rows completes in under 30 s"), not aspirations ("export is fast").
   - Optional sections (`## Boundaries`, `## Assumptions`, `## Open questions`): keep them
     only when they have real content; delete the empty ones rather than leaving
     placeholders. Inside Boundaries, drop the `Always`/`Ask first`/`Never` lines that do not
     apply.
   - No placeholder `<...>` text may remain.
5. **Keep the split rule.** Design, root cause, architecture, and implementation steps the
   user volunteers do not go in the spec. Leave them out and mention in your report that
   they belong in a plan (or an ADR, for a decision that outlives the work).
6. **Add the index line** to `## Index` in `docs/specs/README.md`:
   `- SPEC-YYYYMMDD-slug — draft — <summary>`, in id order (oldest first), at most 120
   characters (shorten the summary for the index if needed), replacing the
   `_No specs yet._` placeholder if it is there.

## Refine

- Never change the `id`, `date`, or filename — the id is permanent, even if the slug no
  longer fits perfectly.
- Resolve open questions the user answered: move the answer into the right section and
  remove the question.
- Keep acceptance criteria specific and testable; split compound criteria.
- If `summary` changes, update the index line in the same edit.
- Refining an `approved` spec in a way that changes what "done" means (scope, requirements,
  acceptance criteria) re-opens it: point this out, and set it back to `draft` (front matter
  and index line together) unless the user confirms the change is approved too.
- `implemented` and `abandoned` specs are history — do not edit their content; a new need
  gets a new spec.

## Transition

Every status change updates the front-matter `status` and the index line together. Only
`draft` and `approved` specs change status; `implemented` and `abandoned` are final.

- **→ `approved`**: only when the user explicitly approves it — never on your own judgement.
  If `## Open questions` still has entries, say so before approving.
- **→ `implemented`**: only from `approved` — a `draft` spec was never agreed, so ask the
  user to approve it first. Check each acceptance criterion against the code, tests, or
  other evidence and tick the ones that hold. Only when all hold, set `implemented`. If
  some cannot be verified or fail, report which and leave the status as it is — the user
  decides.
- **→ `abandoned`**: from `draft` or `approved`; change only the status (front matter and
  index line) and give the reason in your report.
- When a spec becomes `implemented` or `abandoned`, it turns into history. If it settled
  something durable (a decision, a fact, a lesson), suggest recording it as an ADR, memory,
  or learning — the spec itself is no longer guidance.
- Do not delete a spec or remove its index line, whatever its status.

## Out of scope

Point the user elsewhere instead of doing these here:

- the how — approach, design, steps → a plan in `docs/plans/` (it names the spec in its
  `spec:` field);
- a decision with lasting consequences → an ADR in `docs/adrs/`;
- reviewing many records for staleness or duplicates → the `docs-gc` skill;
- renaming records, migrating layouts, or fixing the scaffold → the `docs-doctor` skill.

## Verify

Run the structural check:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor-docs.sh"
```

It must report no finding for the spec you touched or for its index line. Fix any it does
report before finishing. (Findings that already existed elsewhere are not yours to fix here;
mention them.)

## Report

Finish with: the spec's path and id, its status (and the change, if any), what was left in
`## Open questions`, and anything you deliberately left out (design, steps, decisions) with
where it belongs. Do not commit — the record is team-shared and reviewed like any other
change.
