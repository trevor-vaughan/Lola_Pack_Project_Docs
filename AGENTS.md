# docs-discipline — agent context for working on this repo

This repo is the source of the `docs-discipline`
[lola](https://docs.getlola.dev/) pack — two independent skills
(`docs-organization`, `adr`) and six explicit slash commands
(`/docs-init`, `/docs-audit`, `/docs-update`, `/diagram-test`,
`/adr-new`, `/adr-review`). The installable surface lives under
`module/`. The root `Taskfile.yml` wraps lola for install/uninstall plus
the pack's own bash + node + Venom test suite.

## Repo layout

| Path | What it is |
|---|---|
| `module/AGENTS.md` | Lola module manifest (injected into the host's AGENTS.md / CLAUDE.md at install time) |
| `module/skills/docs-organization/SKILL.md` | Skill prompt — invariants, drift detection, diagram authoring |
| `module/skills/docs-organization/scripts/` | `check-structure.sh`, `check-staleness.sh`, `check-prose.mjs`, `check-refs.mjs`, `lint-mermaid.mjs`, `apply-palette.mjs`, `validate-palette.mjs`, `swap-palette.sh`, `contrast.mjs` |
| `module/skills/docs-organization/reference/` | `mermaid-house-style.md`, `readme-template.md`, `docs-tree-template.md`, palette assets |
| `module/skills/adr/SKILL.md` | Skill prompt — MADR 4.0 workflow, status transitions |
| `module/skills/adr/scripts/adr-index.sh` | Regenerates `index.md` whenever a new ADR is added or its status changes |
| `module/skills/adr/reference/` | `madr-template.md`, `review-rubric.md` |
| `module/commands/{docs-init,docs-audit,docs-update,diagram-test,adr-new,adr-review}.md` | The six slash commands |
| `Taskfile.yml` + `.taskfiles/` | Task automation |
| `tests/` | Bash unit tests + node:test unit tests + Venom e2e |
| `eval/` | Headless `/docs-audit` lane evaluation (maintainer research; not installed, not in `task test`). See `eval/README.md`. |
| `.github/workflows/` | CI |

## Working with this pack

- **The pack ships two skills, six commands, no autonomous behavior.**
  Every action requires an explicit `/...` invocation. Do not add
  auto-trigger keywords to either skill's description.
- **Install order matters.** `task install` runs `install:scripts`
  (`npm install` in `module/skills/docs-organization/scripts/`) *before*
  `install:lola`. Lola copies the `scripts/` directory verbatim into the
  assistant's skill directory, so `node_modules` must exist in the
  source. Reverse this order and dev self-tests will fail silently with
  `MERVAL_NOT_INSTALLED`.
- **The slash commands activate the skill, then use `$SKILL_DIR`.**
  Each command file invokes the relevant skill via the host's Skill
  tool. The skill's SKILL.md defines `$SKILL_DIR` (the directory the
  host loaded it from). Reuse `$SKILL_DIR` for every `scripts/...` /
  `reference/...` reference — do not hardcode `.claude/skills/...` or
  search candidate paths.

## Skill-relative helper paths

Both skills (`docs-organization`, `adr`) carry a "Helper paths" preamble
at the top of `SKILL.md` instructing the agent to anchor on the loaded
SKILL.md path:

```bash
SKILL_DIR=$(dirname "$(realpath <skill-md>)")
bash "$SKILL_DIR/scripts/check-structure.sh"
cat "$SKILL_DIR/reference/mermaid-house-style.md"
```

When the `/docs-update` command triggers a `MISSING_ADR_INDEX` finding,
it additionally activates the `adr` skill and binds `$ADR_DIR` from the
loaded `adr/SKILL.md` location the same way.

## Install via lola

`task install` is two steps:

1. `task install:scripts` → `cd module/skills/docs-organization/scripts && npm install`
2. `task install:lola` → `lola mod add` + `lola install`

Default flags are `-a claude-code --scope user`. Pass `-- <flags>` to
override:

```bash
task install ASSISTANT=opencode
task install SCOPE=project
task install -- -f
```

`task uninstall` is the full inverse: `lola uninstall` +
`lola mod rm -f` + `task uninstall:scripts` (`rm -rf node_modules`).

`.lola/`, `.opencode/`, `.cursor/` are gitignored — these are install
destinations or lola registry caches that can land in the working tree
during local install testing.

## Testing

```bash
task test               # all tests (bash + node + venom e2e)
task test:bash          # bash script tests
task test:unit          # node:test unit tests
task test:e2e           # Venom end-to-end
task test:diagrams      # lint + render every mermaid fixture (light + dark)
task lint               # lint every mermaid diagram in the pack's own project docs
```

Tests assert against fixtures under `tests/`. If you add a lint rule or a
new mermaid palette, add a fixture and a corresponding test case.

## Mermaid palettes

Four contrast-validated palettes ship in
`module/skills/docs-organization/reference/`:

- **Solar** (default), **Federation**, **Citrus**, **Parchment**.

Every palette covers every mermaid diagram type (flowchart, sequence,
class, state, ER, journey, gantt, pie, sankey, gitgraph, mindmap,
timeline, xychart, block, kanban, packet, quadrant, requirement, C4,
architecture, radar). The `apply-palette.mjs` and `swap-palette.sh`
helpers automate switching between them; `lint-mermaid.mjs` enforces the
house style.

## Conventions enforced by the skills

1. Top-level `README.md` always self-sufficient for basic user onboarding.
2. Developer documentation under `docs/dev/`.
3. `docs/superpowers/` is in `.gitignore` and never committed.
4. ADRs in `docs/dev/adr/` (or `docs/adr/` for legacy layouts).
5. Every mermaid diagram begins with the house-style init header and uses
   palette classes with WCAG-verified contrast (text/fill ≥ 4.5:1,
   fill/background ≥ 3.0:1 on both light and dark reference backgrounds).

## What NOT to change without explicit user direction

- The six slash-command names — these are the documented public API.
- The two skill names (`docs-organization`, `adr`).
- The MADR 4.0 template structure under
  `module/skills/adr/reference/madr-template.md` — `/adr-new` and
  `/adr-review` both depend on its sections.
- The `install:scripts` → `install:lola` order in `task install`.
- The four palette names + the palette-class naming (`sysA`…`sysF`,
  `edgeLabel`) — every diagram in every project that uses the pack
  references them by name.
