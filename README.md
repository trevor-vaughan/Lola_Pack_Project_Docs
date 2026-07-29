# docs-discipline

A [lola](https://lobstertrap.org/lola/) module with two skills for keeping
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

Install [lola](https://lobstertrap.org/lola/) once:

```bash
uv tool install git+https://github.com/LobsterTrap/lola@v0.7.0
```

Register and install this module:

```bash
lola mod add -n docs-discipline https://github.com/<owner>/lola-mod-project-docs
lola install docs-discipline -a claude-code --scope user
```

`lola install` prompts for assistant and scope when you omit them. Scripted:

```bash
lola install docs-discipline -a opencode --scope user -f
lola install docs-discipline -a claude-code --scope project -f
```

Uninstall mirrors it:

```bash
lola uninstall docs-discipline -a claude-code --scope user -f
lola mod rm -f docs-discipline
```

That is the whole install. The skill's two npm dependencies
(`@aj-archipelago/merval` for mermaid validation, `markdown-it` for the
`/docs-audit` prose and reference lanes) ship pre-bundled inside the module, so
there is no `npm install`, no network access needed after `lola install`, and no
follow-up step.

Requirements: git, Node.js ≥ 20, bash, lola ≥ 0.5.0.

## Quickstart

In a project with the module installed:

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

```text
module/AGENTS.md                            module instructions, injected at install
module/skills/docs-organization/SKILL.md    the docs-organization skill
module/skills/docs-organization/scripts/    node + bash helpers (lint-mermaid.mjs, check-structure.sh, …)
module/skills/docs-organization/scripts/vendor/  pre-built MIT dependency bundles that ship with the skill
module/skills/docs-organization/reference/  house-style references, README/docs templates, palettes
module/skills/adr/SKILL.md                  the adr skill
module/skills/adr/scripts/adr-index.sh      regenerates the ADR index
module/skills/adr/reference/                MADR 4.0 template + review rubric
module/commands/                            the six slash commands
Taskfile.yml                                developer workflow
.taskfiles/scripts/                         shared quality-gate scripts
tests/diagrams/                             mermaid fixtures, one per diagram type
tests/e2e/                                  Venom end-to-end suite
tests/fixtures/                             deliberately-broken modules for the structural linter
tests/lint-structure.bats                   tests for the structural linter
tests/verify-oracle.bats                    tests for the install oracle
eval/                                       /docs-audit lane evaluation (maintainer research)
.github/workflows/                          CI and release
```

Unit tests live beside the code they cover: `*.test.mjs` and `*.test.sh` in
`module/skills/*/scripts/`.

## Where to go next

- **For maintainers/contributors:** `AGENTS.md` at the repo root.
- **For the lola module format:** see <https://lobstertrap.org/lola/>
- **For MADR:** see <https://adr.github.io/madr/>

## License

See `LICENSE`.
