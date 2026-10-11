---
name: docs-spec
description: Create, refine, and manage the lifecycle of a spec record in the agentic docs/specs/ folder - draft a SPEC-YYYYMMDD-slug.md from a feature request, bug report, or ticket, tighten its scope and acceptance criteria, and move it through draft, approved, implemented, or abandoned. Use whenever the user asks to write, update, approve, close, or abandon a spec, to capture requirements or acceptance criteria before implementing a feature, bug fix, or change, or to "spec out" a ticket - even if they do not say "spec". Not for design or implementation plans (plans and ADRs).
argument-hint: "[ticket link | SPEC-YYYYMMDD-slug] [request]"
---

Author and maintain one spec record in `docs/specs/` so that it follows the folder's
conventions exactly. A spec states **what** is needed and **why** — objective, scope,
requirements, acceptance criteria — so that someone (human or agent) can later plan and
verify the work without re-asking. How it gets built belongs in a plan.

This skill imposes no workflow: it never decides that a spec must exist before a plan, and it
never approves a spec on its own. It only makes the record right.

## Before anything

1. If `docs/specs/README.md` does not exist, stop and suggest the `docs-init` skill; if
   `docs/specs/spec.template.md` does not, stop and suggest the `docs-doctor` skill.
2. Read `docs/specs/README.md`: it is the source of truth for naming, statuses, the split
   rule, and the index-line format, and wins wherever it and this skill disagree.
3. Pick the mode: **Create**, **Refine** (change content), or **Transition** (change status).
   A request can combine them ("tighten SPEC-… and approve it").

## Create

1. **Avoid duplicates.** If the `docs/specs/README.md` index has a live (`draft`/`approved`)
   spec on the same topic, offer to refine it instead.
2. **Gather what makes it testable**, from the request, any linked ticket you can read, and
   the code:
   - the objective — what is needed, why, and who benefits;
   - the scope — what is in, and explicit non-goals;
   - the `type` — `feature`, `bug`, or `change`; for a bug, observed versus expected
     behaviour (and how to reproduce it, if known);
   - acceptance criteria — specific conditions someone could check.

   Ask the user, in one batch of short questions, only about gaps that would leave the spec
   untestable or its scope ambiguous — never about what the code or ticket already says.
   Unanswered gaps go under `## Open questions` — never invent requirements to fill them.
3. **Name it** `SPEC-<today as YYYYMMDD>-<slug>` with a kebab-case noun-phrase slug of at
   most 4 words (`bulk-export`), checking that no file with that name exists.
4. **Write `docs/specs/<id>.md` by copying `docs/specs/spec.template.md`** — never from
   memory; the repo's copy may be newer than this skill.
   - Front matter: `id` = the file stem, `status: draft`, `type`, `date` = today, `source` =
     the ticket link or `none`, `summary` = one line saying what is needed and why. Keep the
     `# vocabulary` comments, and quote a value that contains `: `
     (`summary: "Export: add CSV"`).
   - `## Objective`: self-contained — restate the ticket so a reader without tracker access
     understands it.
   - `## Scope`: fill both `- In:` and `- Out:` (`- Out: none` if there are no non-goals).
   - `## Requirements`: the behaviour to deliver; for a bug, observed versus expected.
   - `## Acceptance criteria`: unticked `- [ ]` items, each observable and checkable
     ("export of 10k rows completes in under 30 s", not "export is fast").
   - `## Boundaries`, `## Assumptions`, `## Open questions`: keep them only with real
     content, else delete them; in Boundaries, drop the `Always`/`Ask first`/`Never` lines
     that do not apply.
   - No `<...>` placeholder text may remain.
5. **Keep the split rule.** Design, root cause, architecture, and implementation steps stay
   out of the spec — report them as belonging in a plan (`docs-plan`), or an ADR for a
   decision that outlives the work.
6. **Index it**: add `- <id> — draft — <summary>` to `## Index` in id order, at most 120
   characters (shorten the summary if needed), replacing `_No specs yet._` if present.

## Refine

- `id`, `date`, and filename never change, even if the slug no longer fits.
- Move answered open questions into the right section and delete them.
- Keep acceptance criteria specific and testable; split compound ones.
- A changed `summary` updates the index line in the same edit.
- Changing what "done" means for an `approved` spec (scope, requirements, acceptance
  criteria) re-opens it: say so, and set it back to `draft` unless the user confirms the
  change is approved too.
- `implemented` and `abandoned` specs are history: never edit them; a new need gets a new
  spec.

## Transition

Every status change updates the front-matter `status` and the index line together.
`implemented` and `abandoned` are final.

- **→ `approved`**: only when the user explicitly approves it — never on your own judgement.
  Say so first if `## Open questions` still has entries. Once approved, point out that the
  natural next step is a plan built from it (`docs-plan`).
- **→ `implemented`**: only from `approved` — ask the user to approve a `draft` first. Check
  each acceptance criterion against the code, tests, or other evidence, ticking what holds;
  set `implemented` only when every criterion is ticked. Otherwise report what fails or
  cannot be verified and leave the status — the user decides.
- **→ `abandoned`** from `draft` or `approved`: change only the status and give the reason
  in the report.
- On `implemented` or `abandoned`, suggest recording anything durable the spec settled (a
  decision, fact, or lesson) as an ADR, memory, or learning.
- Never delete a spec or its index line.

## Out of scope

Approach, design, and steps → a plan (`docs-plan`; it names the spec in `spec:`); a lasting
decision → an ADR in `docs/adrs/`; staleness or duplicates across records → `docs-gc`;
renames, layout migrations, or scaffold repairs → `docs-doctor`.

## Verify

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor-docs.sh"
```

Fix every finding for the spec you touched or its index line before finishing; mention
findings that already existed elsewhere without fixing them.

## Report

The spec's path and id; its status (and the change, if any); what is left in
`## Open questions`; and anything left out (design, steps, decisions) with where it belongs.
Do not commit — the record is team-shared and reviewed like any other change.
