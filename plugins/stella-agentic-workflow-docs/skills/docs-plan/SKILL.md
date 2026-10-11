---
name: docs-plan
description: Create, refine, and manage the lifecycle of a plan record in the agentic docs/plans/ folder - draft a PLAN-YYYYMMDD-slug.md from a spec or a request, ground its steps in the code, tick steps as work completes, and move it through proposed, in-progress, done, or abandoned. Use whenever the user asks to write, update, start, finish, or abandon a plan, to plan how to implement a spec, feature, bug fix, or migration, or to record progress on one - even if they do not say "plan". Not for requirements (specs) or for doing the implementation.
argument-hint: "[SPEC-YYYYMMDD-slug | PLAN-YYYYMMDD-slug] [request]"
---

Author and maintain one plan record in `docs/plans/` so that it follows the folder's
conventions exactly. A plan states **how** something will be done — approach, steps, risks,
verification — so that someone (human or agent) can carry it out and check it without
re-deriving the design. What is needed and why belongs in a spec.

The natural flow is spec → plan, so this skill looks for a spec first and offers to write one
when it is missing; a plan may still stand alone with `spec: none`. Beyond that it imposes no
workflow — it never requires an approved spec or a review before work starts — and it does
not implement the plan. It only makes the record right.

## Before anything

1. If `docs/plans/README.md` does not exist, stop and suggest the `docs-init` skill; if
   `docs/plans/plan.template.md` does not, stop and suggest the `docs-doctor` skill.
2. Read `docs/plans/README.md`: it is the source of truth for naming, statuses, the split
   rule, and the index-line format, and wins wherever it and this skill disagree.
3. Pick the mode: **Create**, **Refine** (change content, including ticking steps), or
   **Transition** (change status). A request can combine them ("tick step 3 of PLAN-… and
   mark it done").

## Create

1. **Start from the spec.** Use the one the request names; otherwise look for a live
   (`draft`/`approved`) spec on the topic in the `docs/specs/README.md` index, and confirm it
   with the user if in doubt.
   - Found: the plan must cover every acceptance criterion. A `draft` spec is noted in the
     report, not refused — the workflow decides whether that matters.
   - None: offer to write one first with the `docs-spec` skill. If the user declines, or the
     work is too small to need one, continue with `spec: none`.
   - `implemented` and `abandoned` specs are history: plan from a new spec, or none.
2. **Avoid duplicates.** If the `docs/plans/README.md` index has a live
   (`proposed`/`in-progress`) plan on the same topic or spec, offer to refine it instead.
3. **Ground it.** Every step must hold against:
   - **ADRs** — the accepted ones whose `scope` touches the work. If the plan has to
     contradict one, stop and say so: that needs a new ADR first.
   - **Project instructions** (`CLAUDE.md` and the like) — conventions, required checks,
     rules for changes. A step that cannot follow them is an open question.
   - **Memories and learnings** on this area — known facts and past failures to account for.
   - **The stack** — languages, frameworks, and versions from the manifests and lockfiles.
     Plan with what is installed; a new dependency or version change is a step of its own,
     named in `## Approach`.
   - **The code** — real files, existing patterns, the repo's test and check commands. Reuse
     what is there rather than inventing a parallel mechanism.
4. **Settle the approach**: the chosen design (for a bug, the root cause), rejected
   alternatives with why, and how the whole will be verified. Ask the user, in one batch of
   short questions, only about choices that would change the steps and that the spec, ADRs,
   instructions, and code do not settle. Unanswered choices go under `## Open questions` —
   never present a guess as decided.
5. **Name it** `PLAN-<today as YYYYMMDD>-<slug>` with a kebab-case verb-phrase slug of at
   most 4 words (`add-bulk-export`), checking that no file with that name exists.
6. **Write `docs/plans/<id>.md` by copying `docs/plans/plan.template.md`** — never from
   memory; the repo's copy may be newer than this skill.
   - Front matter: `id` = the file stem, `status: proposed`, `date` = today, `spec` = the
     spec's id or `none`, `adrs` = the accepted ADRs it relies on, comma-separated, or
     `none`, `summary` = one line. Keep the `# vocabulary` comment, and quote a value that
     contains `: ` (`summary: "Auth: move to OIDC"`).
   - `## Approach`: the design or root cause, then rejected alternatives, one line each.
     With `spec: none`, open with a sentence or two on what the plan is for.
   - `## Steps`: `- [ ] N.` items in the order they will be done, numbered continuously,
     each small enough to do and check on its own, with `- Files:` and `- Verify:` (a test,
     command, or manual check). Use `### Phase N: <name>` headings, each closed by a
     `- [ ] Checkpoint:` line, only for long plans with natural stages; otherwise drop both.
   - `## Verification`: how to confirm the whole plan is done, covering every acceptance
     criterion of the spec.
   - `## Risks` (`- <risk> — high | med | low — <mitigation>`) and `## Open questions`
     (implementation questions only): keep them only with real content, else delete them.
   - No `<...>` placeholder text may remain.
7. **Keep the split rule.** Requirements or acceptance criteria the spec lacks stay out of
   the plan — report them as belonging in the spec (`docs-spec`). A decision that should
   outlive the plan (a convention, dependency, or architectural choice) needs its own ADR:
   report it, and add it to `adrs:` only once it is accepted.
8. **Index it**: add `- <id> — proposed — <summary>` to `## Index` in id order, at most 120
   characters (shorten the summary if needed), replacing `_No plans yet._` if present.

## Refine

- `id`, `date`, and filename never change, even if the slug no longer fits.
- **Ticking**: tick a step (`- [x]`) only when its `Verify:` holds against the code, tests,
  or command output — not on say-so — and a checkpoint only when everything it names holds.
- **Changing course**: rewrite or add unticked steps in place and renumber only those; keep
  ticked steps as the record of what was done (never untick to hide rework — add a step);
  add the abandoned direction to the rejected alternatives in `## Approach`, with why.
- Move answered open questions into the right section and delete them.
- A changed `summary` updates the index line in the same edit; a changed `spec:` or `adrs:`
  follows the Create rules.
- A change to what the spec requires is a spec change: point to `docs-spec` instead.
- `done` and `abandoned` plans are history: never edit them; new work gets a new plan.

## Transition

Every status change updates the front-matter `status` and the index line together. `done`
and `abandoned` are final.

- **→ `in-progress`** from `proposed`, when work starts — ticking a first step implies it.
- **→ `done`** from `in-progress` (or `proposed`, if the work finished without being marked
  started). Check every step, checkpoint, and `## Verification` against evidence, ticking
  what holds; set `done` only when all hold. Otherwise report what fails or cannot be
  verified and leave the status — the user decides. A step the user chooses to drop is
  removed through Changing course first; a `done` plan has no unticked box.
- **→ `abandoned`** from `proposed` or `in-progress`: change only the status and give the
  reason in the report.
- On `done`, if the plan names a spec, point out that it may be ready for `implemented`
  (`docs-spec`) — never change the spec from here. On `done` or `abandoned`, suggest
  recording anything durable the work settled (a decision, fact, or lesson, including why it
  was abandoned) as an ADR, memory, or learning.
- Never delete a plan or its index line.

## Out of scope

Requirements and acceptance criteria → a spec (`docs-spec`); a lasting decision → an ADR in
`docs/adrs/`; doing the work → outside this skill; staleness or duplicates across records →
`docs-gc`; renames, layout migrations, or scaffold repairs → `docs-doctor`.

## Verify

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/doctor-docs.sh"
```

Fix every finding for the plan you touched or its index line before finishing; mention
findings that already existed elsewhere without fixing them.

## Report

The plan's path and id; its status (and the change, if any); its spec and ADRs; which steps
are ticked; what is left in `## Open questions`; and anything left out (requirements,
decisions) with where it belongs. Do not commit — the record is team-shared and reviewed like
any other change.
