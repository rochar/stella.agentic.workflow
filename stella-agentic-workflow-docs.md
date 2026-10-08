# stella-agentic-workflow-docs — visual map

A visual overview of the [`stella-agentic-workflow-docs`](plugins/stella-agentic-workflow-docs/README.md)
plugin: what it ships, how it changes what Claude sees in a session, and how the `docs/` tree
it maintains is organised. The plugin README and the folder `README.md`s remain the reference
for the exact rules; this file shows how the pieces fit together.

## 1. Inventory

Every kind of artifact a Claude Code plugin can ship, and what this one provides.

| Artifact type | Shipped | Path (under `plugins/stella-agentic-workflow-docs/`) |
| --- | --- | --- |
| Manifest | yes | `.claude-plugin/plugin.json` |
| Hooks | `SessionStart`, `Stop` | `hooks/hooks.json` → `hooks-handlers/session-start.sh`, `hooks-handlers/stop.sh` |
| Injected context | yes (≤ 200 words) | `context/docs-structure.md` |
| Skills | `docs-init`, `docs-doctor`, `docs-gc`, `docs-spec` | `skills/<name>/SKILL.md` |
| Scripts | `init-docs.sh`, `doctor-docs.sh`, shared `lib/template-files.sh` | `scripts/` |
| Scaffold (data) | the `docs/` tree with READMEs and templates | `templates/docs/` |
| Agents (subagents) | none | — |
| Slash commands | none (skills are invoked as `/stella-agentic-workflow-docs:<skill>`) | — |
| MCP servers | none | — |
| Output styles | none | — |

## 2. Component map

`templates/docs/` is the single source of truth: the bootstrapper copies it, both hooks check
against it, and the doctor derives its checks from it — all through one shared helper.

```mermaid
flowchart LR
    MP[".claude-plugin/marketplace.json<br/>stella-agentic marketplace"] --> PJ["plugin.json<br/>manifest"]
    PJ --> HJ["hooks/hooks.json"]
    PJ --> SK["skills/"]

    HJ -- SessionStart --> SS["session-start.sh"]
    HJ -- Stop --> ST["stop.sh"]
    SS -- prints --> CTX["context/docs-structure.md"]

    SK --> DI["docs-init"]
    SK --> DD["docs-doctor"]
    SK --> GC["docs-gc"]
    SK --> SP["docs-spec"]
    DI --> INIT["scripts/init-docs.sh"]
    DD --> DOC["scripts/doctor-docs.sh"]
    GC -- "check only" --> DOC
    SP -- "check only" --> DOC

    SS --> LIB["scripts/lib/template-files.sh"]
    ST --> LIB
    INIT --> LIB
    DOC --> LIB
    LIB --> TPL[("templates/docs/<br/>source of truth")]

    INIT -- "copies, never overwrites" --> REPO[("consuming repo<br/>docs/")]
    DOC -- "checks / --fix scaffold" --> REPO
    SS -- "is it bootstrapped?" --> REPO
    ST -- "is it bootstrapped?" --> REPO
```

## 3. How a session learns the conventions

Claude Code runs the `SessionStart` hook for every session — CLI, desktop, or cloud. Whatever
the hook prints to stdout is added to the model's context, so the agent starts already knowing
the `docs/` layout. Skills appear to the model only as a name and description until invoked.

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant SS as session-start.sh
    participant FS as Repository docs/
    participant M as Model context

    CC->>SS: SessionStart (CLAUDE_PLUGIN_ROOT, CLAUDE_PROJECT_DIR)
    SS->>SS: cat context/docs-structure.md
    SS->>FS: every templates/docs file present under docs/?
    alt all present
        FS-->>SS: yes
        SS-->>CC: conventions only
    else none present
        FS-->>SS: none
        SS-->>CC: conventions + NOTE: run docs-init
    else some present (older bootstrap)
        FS-->>SS: partial
        SS-->>CC: conventions + NOTE: run docs-doctor
    end
    CC->>M: hook stdout appended to context
    CC->>M: skill names + descriptions (bodies load only when invoked)
```

## 4. How the context changes during a session

The injected text is a thin pointer; detail is pulled in lazily, only as far as the task
needs. The `Stop` hook adds one more piece of guidance at the session's first stop.

```mermaid
flowchart TD
    A["System prompt + CLAUDE.md"] --> B["+ docs-structure.md<br/>(injected at SessionStart)"]
    B --> C{"docs/ bootstrapped?"}
    C -- no --> N["+ NOTE: docs-init / docs-doctor"]
    C -- yes --> L1
    N --> L1
    L1["Read folder README index lines<br/>(is there a decision or plan about X?)"] --> L2["Read a record's front matter<br/>(status, summary)"]
    L2 --> L3["Open the record body<br/>(only when needed)"]
    L3 --> W["Write or update records<br/>+ index line in the same change"]
    W --> S["First Stop: hook reason injected<br/>'record anything durable, or finish'"]
```

## 5. How the Stop hook recognises a session

Claude Code fires `Stop` at the end of every assistant turn, and no hook can know which stop is
the last. The hook therefore nudges only the session's **first** stop, keyed on the
`session_id` in the hook payload, and never blocks the same stop twice.

```mermaid
flowchart TD
    IN["Hook payload on stdin<br/>(session_id, stop_hook_active)"] --> A{"stop_hook_active = true?"}
    A -- yes --> PASS["exit 0: let the stop through"]
    A -- no --> B{"session_id present?"}
    B -- yes --> M{"marker exists?<br/>$TMPDIR/stella-agentic-workflow-docs-uid/nudged-session_id"}
    M -- yes --> PASS
    M -- no --> D
    B -- "no (manual run)" --> D{"docs/ fully bootstrapped?"}
    D -- no --> PASS
    D -- yes --> W["write marker (dir mode 700)"]
    W --> BLK["stdout: decision = block<br/>reason = record anything durable, else finish"]
    BLK --> AG["Agent continues once:<br/>writes records or finishes"]
    AG --> IN
```

## 6. How `docs/` is organised

Five typed folders. Each folder's `README.md` holds its conventions and its index; each ships
one `*.template.md` that every record starts from.

```mermaid
flowchart TD
    ROOT["docs/README.md<br/>entry point"] --> ADR["adrs/<br/>decisions"]
    ROOT --> SPEC["specs/<br/>what to build and why"]
    ROOT --> PLAN["plans/<br/>how to build it"]
    ROOT --> MEM["memories/<br/>durable facts"]
    ROOT --> LRN["learnings/<br/>failures, gotchas"]

    ADR --> ADRf["README.md (rules + index)<br/>adr.template.md<br/>ADR-YYYYMMDD-slug.md"]
    SPEC --> SPECf["README.md (rules + index)<br/>spec.template.md<br/>SPEC-YYYYMMDD-slug.md"]
    PLAN --> PLANf["README.md (rules + index)<br/>plan.template.md<br/>PLAN-YYYYMMDD-slug.md"]
    MEM --> MEMf["README.md (rules + index)<br/>memory.template.md<br/>MEM-YYYYMMDD-slug.md"]
    LRN --> LRNf["README.md (rules + index)<br/>learning.template.md<br/>LRN-YYYYMMDD-slug.md"]
```

| Folder | Prefix | Front matter (besides `id`, `date`, `summary`) | Index line |
| --- | --- | --- | --- |
| `adrs/` | `ADR-` | `status`, `superseded-by`, `scope` | `- ADR-… — status — summary` |
| `specs/` | `SPEC-` | `status`, `type`, `source` | `- SPEC-… — status — summary` |
| `plans/` | `PLAN-` | `status`, `spec`, `adrs` | `- PLAN-… — status — summary` |
| `memories/` | `MEM-` | `type`, `verified` | `- MEM-… — type — summary` |
| `learnings/` | `LRN-` | `obsolete` | `- LRN-… — summary` |

Records are named `<PREFIX>-YYYYMMDD-slug.md` (creation date, slug of at most 4 words); the
whole stem is the id, and index lines stay at most 120 characters. Records reference each
other by id:

```mermaid
flowchart LR
    PLAN["PLAN"] -- "spec:" --> SPEC["SPEC"]
    PLAN -- "adrs:" --> ADR["ADR (accepted)"]
    ADR -- "superseded-by:" --> ADR2["newer ADR"]
    LRN["LRN"] -. "obsolete: merged into" .-> LRN2["older LRN"]
```

## 7. Record lifecycles

Statuses are kept in both the front matter and the index line. Nothing is ever renumbered or
erased: retired records keep their index line, so ids are never reused.

```mermaid
stateDiagram-v2
    direction LR
    state "ADR" as adr {
        [*] --> proposed
        proposed --> accepted
        proposed --> rejected
        accepted --> superseded
    }
    state "SPEC" as spec {
        [*] --> draft
        draft --> approved
        approved --> draft: re-opened by a change to what done means
        approved --> implemented
        draft --> abandoned
        approved --> abandoned
    }
    state "PLAN" as plan {
        [*] --> plan_proposed
        plan_proposed --> in_progress
        in_progress --> done
        plan_proposed --> plan_abandoned
        in_progress --> plan_abandoned
    }
```

```mermaid
stateDiagram-v2
    direction LR
    state "MEM" as mem {
        [*] --> current
        current --> current: re-verified (verified date bumped)
        current --> deleted: no longer relevant (file removed, index line kept with deleted suffix)
    }
    state "LRN" as lrn {
        [*] --> applies
        applies --> obsolete: lesson no longer applies (obsolete field + index suffix)
    }
```

(`plan_proposed`, `in_progress`, `plan_abandoned` are the plan statuses `proposed`,
`in-progress`, `abandoned`; renamed only so the diagram keeps them distinct from ADR and spec
states.)

## 8. Which skill to run

Every skill leaves a diff for human review — none of them commits. `docs-spec` works on one
spec record at a time, on a bootstrapped tree, whenever a spec is written or changes status.

```mermaid
flowchart TD
    START{"State of docs/"} -- "missing" --> INIT["/docs-init<br/>init-docs.sh: copy templates/docs,<br/>idempotent, never overwrites"]
    START -- "partial, outdated after a plugin update,<br/>or records written ad hoc" --> DOC
    START -- "structurally clean" --> GC
    START -- "write, refine, or change the<br/>status of one spec" --> SP

    DOC["/docs-doctor"] --> D1["doctor-docs.sh --fix<br/>repair scaffold"]
    D1 --> D2["[record] findings:<br/>migrate layout, rename, fix metadata and indexes"]
    D2 --> D3["[stray] findings:<br/>adopt as records or leave alone"]
    D3 --> D4["re-run doctor-docs.sh until clean"]

    GC["/docs-gc"] --> G0{"doctor-docs.sh clean?"}
    G0 -- no --> DOC
    G0 -- yes --> G1["memories: re-verify or delete<br/>learnings: mark obsolete<br/>merge duplicates<br/>fix dead spec / plan statuses<br/>tighten prose"]

    INIT --> REVIEW["Human reviews the diff and commits"]
    D4 --> REVIEW
    G1 --> REVIEW

    SP["/docs-spec"] --> S1["create: interview for gaps,<br/>copy spec.template.md, add index line<br/>refine: id and date never change<br/>transition: status + index line together"]
    S1 --> S2["doctor-docs.sh: no new findings"]
    S2 --> REVIEW
```

## Keeping this map current

This file must be updated in the same change as any change to the plugin's artifacts — see
the Conventions in [CLAUDE.md](CLAUDE.md). `scripts/checks.sh` fails when a skill, hook
handler, agent, or command exists in the plugin but is not mentioned here.
