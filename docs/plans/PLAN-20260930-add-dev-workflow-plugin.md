---
id: PLAN-20260930-add-dev-workflow-plugin
status: proposed # proposed | in-progress | done | abandoned
date: 2026-09-30
spec: none
adrs: none
summary: Dev-workflow plugin skeleton with its dependencies
---
## Approach
Add a second plugin, `stella-agentic-workflow-dev` (displayName `stella.agentic.workflow.dev`),
to the `stella-agentic` marketplace. It is an opinionated development workflow
(spec → plan → review → implement → simplify → review → commit) built on the docs plugin.
This version is a skeleton: manifest, dependencies, and deployment of
`docs/stella-agentic-workflow-dev/workflow.md` and `docs/stella-agentic-workflow-dev/config.md`.
No skills yet.

- **Dependencies** go in `plugin.json` `"dependencies"`: `stella-agentic-workflow-docs`
  (same marketplace, so a bare name), `commit-commands@claude-plugins-official` and
  `context7@claude-plugins-official`. The two cross-marketplace dependencies install only if
  `marketplace.json` lists `claude-plugins-official` in `allowCrossMarketplaceDependenciesOn`.
  `claude-plugins-official` is registered automatically, so it needs no
  `extraKnownMarketplaces` entry.
- **context7** comes from its official plugin, which ships `.mcp.json` pointing at
  `https://mcp.context7.com/mcp` with an optional `CONTEXT7_API_KEY`.
  - Rejected: bundling our own `.mcp.json`, which would duplicate the official server config
    and need its own upkeep.
- **Deployment** happens in a SessionStart hook that calls `scripts/deploy-workflow.sh`.
  It runs only when the docs framework is set up (`docs/README.md` exists). Otherwise it
  points at `/stella-agentic-workflow-docs:docs-init` and creates nothing, so repos that
  enable the plugin at user scope don't get a stray `docs/`.
  - `workflow.md` belongs to the plugin and is always overwritten when it differs from the
    template.
  - `config.md` belongs to the repo: created if missing, never overwritten. A later skill
    will migrate it when the default config structure changes.
- **Location**: `docs/stella-agentic-workflow-dev/`, named after the plugin, with lowercase
  filenames. The request said `doc/`, but the framework root is `docs/`.
- The separate plugin, the dependency mechanism, and the overwrite/never-overwrite split are
  recorded as `ADR-0002-dev-workflow-plugin` (step 5). Add it to `adrs:` once it is accepted.

## Steps

### Phase 1: Plugin skeleton
- [ ] 1. Manifest and marketplace entry
  - Files: `plugins/stella-agentic-workflow-dev/.claude-plugin/plugin.json` (version `0.1.0`,
    same author, homepage and repository as the docs plugin, `dependencies` as above);
    `.claude-plugin/marketplace.json` (new plugin entry and
    `"allowCrossMarketplaceDependenciesOn": ["claude-plugins-official"]`);
    `.claude/settings.json` (enable `stella-agentic-workflow-dev@stella-agentic` to dogfood it)
  - Verify: `jq empty` on each file
- [ ] 2. Workflow templates
  - Files: `plugins/stella-agentic-workflow-dev/templates/stella-agentic-workflow-dev/workflow.md`:
    - a header note: managed by the plugin, overwritten every session, overrides go in
      `config.md`, which takes precedence;
    - a mermaid flowchart: Spec → Plan → Review plan (on a Blocker, back to Plan, or to Spec
      if the spec is wrong) → Implement → Simplify → Review code (on a Blocker, back to
      Implement, or to Plan if the plan is wrong) → Commit;
    - a table of steps, each with what it produces and which tool drives it: `docs/specs/`,
      `docs/plans/`, context7 for library docs, `/simplify`, `/code-review`,
      `/commit-commands:commit`;
    - review severities: **Blocker** stops the flow and goes back a step; **Major** must be
      fixed or explicitly accepted and recorded; **Minor** is flagged and the author fixes or
      defers it.

    `templates/stella-agentic-workflow-dev/config.md`: a header explaining that it overrides `workflow.md`
    and is never overwritten; empty body (`_No overrides._`)
  - Verify: the mermaid diagram renders in the GitHub preview
- [ ] 3. Deploy script and SessionStart hook
  - Files: `scripts/deploy-workflow.sh` (idempotent, `cmp` before copying, reports only
    changes); `hooks/hooks.json` (same shape as the docs plugin's);
    `hooks-handlers/session-start.sh`, following the docs hook's style:
    - `set -uo pipefail`;
    - self-locating when `CLAUDE_PLUGIN_ROOT` is unset;
    - on failure, a stderr warning and `exit 0` so the context it printed is kept.

    The hook prints `context/dev-workflow.md` and then the deploy result.
    `context/dev-workflow.md` is a thin pointer of about 80 words or fewer.
  - Verify: run the script twice on a tmp repo, with and without a bootstrapped `docs/`;
    run the hook by hand as `CLAUDE.md` describes for the docs hook
- [ ] Checkpoint: the hook deploys both files into a bootstrapped tmp repo and does nothing
  on a second run

### Phase 2: Checks, dogfooding, docs
- [ ] 4. Extend `scripts/checks.sh`
  - Files: `scripts/checks.sh`:
    - step 5 skips the `docs/stella-agentic-workflow-dev/` subtree;
    - new deploy tests: no-op without `docs/`; creates both files; second run has nothing to
      do; an edited `workflow.md` is restored; an edited `config.md` survives; the hook
      prints its context;
    - this repo's `docs/stella-agentic-workflow-dev/workflow.md` matches the template byte-for-byte;
    - every `name@marketplace` dependency's marketplace is on the allowlist;
    - the word-budget check runs over both context files.
  - Verify: `bash scripts/checks.sh`
- [ ] 5. Dogfood the files and record the decision
  - Files: `docs/stella-agentic-workflow-dev/workflow.md`, `docs/stella-agentic-workflow-dev/config.md`,
    `docs/adrs/ADR-0002-dev-workflow-plugin.md` and its index line (following
    `docs/adrs/README.md`)
  - Verify: `bash plugins/stella-agentic-workflow-docs/scripts/doctor-docs.sh .` exits 0
- [ ] 6. Documentation
  - Files: plugin `README.md`; `CLAUDE.md`:
    - a Project Structure entry for the new plugin;
    - a Conventions entry: `workflow.md` is always overwritten and `config.md` never is; edit
      the templates, not the deployed copies;
    - Tests entries.

    Root `README.md`: a section on the development workflow plugin (how to enable it,
    auto-installed dependencies, optional `CONTEXT7_API_KEY`).
  - Verify: read-through; all links resolve
- [ ] Checkpoint: `bash scripts/checks.sh` passes

## Risks
- The cross-marketplace dependency is silently skipped if the allowlist is wrong — med —
  checks.sh verifies the allowlist; test a real install.
- A SessionStart hook that writes to the working tree surprises users with diffs after
  plugin updates — low — this is intended; the header of `workflow.md` explains it.
- Users edit `workflow.md` by hand and lose the edits — med — the header note says to use
  `config.md`, and the hook reports when it restored the file.

## Open questions
- Should the `stella-agentic-workflow-docs` dependency be pinned to a version range (e.g.
  `^0.3.0`)? The default is unpinned, tracking the latest.
- Resolved: whether a plan may be a flat file rather than a `NNNN-slug/plan.md` directory —
  `ADR-20260930-single-file-records` makes every plan a single `PLAN-YYYYMMDD-slug.md` file.

## Verification
- `bash scripts/checks.sh` passes.
- In Claude Code, run `/plugin marketplace update stella-agentic`, then
  `/plugin install stella-agentic-workflow-dev@stella-agentic`. The docs plugin,
  `commit-commands` and `context7` should install as dependencies, and `/mcp` should list
  context7.
- A new session in a bootstrapped repo gets `docs/stella-agentic-workflow-dev/workflow.md` and `config.md`.
  Editing both and restarting restores `workflow.md` and keeps `config.md`.
