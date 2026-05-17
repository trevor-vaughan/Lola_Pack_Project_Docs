# docs-discipline

A [lola](https://lobstertrap.org/lola/) pack with two skills for keeping
technical project documentation on track, current, and consistent. Nothing
auto-invokes — every behavior is reached through an explicit slash command.

----

> 🤖 LLM/AI WARNING 🤖
>
> This project was written with LLM (AI) assistance.

----

## What this is

`docs-discipline` ships two independent skills for AI coding assistants:

- **docs-organization** — manages README and `docs/` layout, detects drift
  between code and documentation, validates mermaid diagrams against a
  house style (palette + WCAG contrast).
- **adr** — manages Architectural Decision Records (MADR 4.0) with an
  inline self-review pass on creation and a context-isolated subagent
  review pass on demand.

Behavior reaches the agent only through six explicit slash commands:
`/docs-init`, `/docs-audit`, `/docs-update`, `/diagram-test`, `/adr-new`,
`/adr-review`.

## Install

```bash
# Install lola (one time):
uv tool install git+https://github.com/LobsterTrap/lola

# Install this pack:
task install                                      # default: claude-code, user scope
task install ASSISTANT=opencode          # install for OpenCode
task install SCOPE=project    # opt into project scope
task install -- -f    # force-overwrite after edits
```

Requirements: git, Node.js ≥20, bash, lola.

`task install` runs **two** steps:

1. `install:scripts` — `npm install` inside
   `module/skills/docs-organization/scripts/`, so the project's own
   `task test:diagrams` and `task lint` work locally.
2. `install:lola` — `lola mod add` + `lola install`.

**Note on `merval` at install time.** Lola excludes `node_modules/` from
the install (it's in its built-in `ALWAYS_IGNORE` list). On first
`/diagram-test` invocation after `task install`, the skill detects
missing `@aj-archipelago/merval` and surfaces a `MERVAL_NOT_INSTALLED`
finding with the exact path and command to run (`npm install` inside the
installed `scripts/` dir). That one-shot user step is the supported
workflow.

Uninstall mirrors install:

```bash
task uninstall                                    # full inverse
```

## Quickstart

In a project with the pack installed:

```bash
/docs-init                                        # scaffold README, docs/, .gitignore
/docs-audit                                       # find drift between code and docs (read-only)
/docs-update                                      # apply fixes interactively
/diagram-test                                     # lint every mermaid diagram
/adr-new "Use Postgres for primary storage"       # draft an ADR with inline self-review
/adr-review 0001                                  # independent rubric review via subagent
```

## Diagram palettes

Four contrast-validated mermaid palettes ship with the skill:

- **Solar** (default) — cool jewel tones, outlined clusters, both light and
  dark backgrounds
- **Federation** — cool balanced, outlined clusters, both backgrounds
- **Citrus** — warm earth tones, outlined clusters, both backgrounds
- **Parchment** — filled beige clusters for high-impact light-bg rendering

Every palette covers every mermaid diagram type (flowchart, sequence,
class, state, ER, journey, gantt, pie, sankey, gitgraph, mindmap,
timeline, xychart, block, kanban, packet, quadrant, requirement, C4,
architecture, radar). See
`module/skills/docs-organization/reference/mermaid-house-style.md` for
templates and the deltas table for switching between them. Two convenience
targets:

```bash
task render -- path/to/diagram.mmd                # render to PNG (light + dark)
task palette -- citrus path/to/diagram.mmd        # swap palette on an existing file
```

## Conventions enforced

1. Top-level `README.md` always self-sufficient for basic user onboarding.
2. Developer documentation under `docs/dev/`.
3. `docs/superpowers/` is in `.gitignore` and never committed.
4. ADRs in `docs/dev/adr/` (or `docs/adr/` for legacy layouts).
5. Every mermaid diagram begins with the house-style init header and uses
   palette classes with WCAG-verified contrast.

## Project structure

```
module/AGENTS.md                                       # lola module manifest
module/skills/docs-organization/SKILL.md               # docs-organization skill
module/skills/docs-organization/scripts/               # node + bash helpers (lint-mermaid.mjs, check-structure.sh, …)
module/skills/docs-organization/reference/             # house-style references, README/docs templates
module/skills/adr/SKILL.md                             # adr skill
module/skills/adr/scripts/                             # adr-index.sh
module/skills/adr/reference/                           # MADR 4.0 template + review rubric
module/commands/{docs-init,docs-audit,docs-update,diagram-test,adr-new,adr-review}.md
Taskfile.yml                                           # install / uninstall / dev workflow
.taskfiles/                                            # task automation modules
tests/                                                 # bash + node unit tests, venom e2e
.github/workflows/                                     # CI
```

## Where to go next

- **For maintainers/contributors:** `AGENTS.md` at the repo root.
- **For the lola pack format:** see https://lobstertrap.org/lola/
- **For MADR:** see https://adr.github.io/madr/

## License

See `LICENSE`.
