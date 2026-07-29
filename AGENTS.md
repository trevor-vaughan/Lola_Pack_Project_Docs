# docs-discipline — agent context for working on this repo

This repo is the source of the `docs-discipline`
[lola](https://lobstertrap.org/lola/) module — two independent skills
(`docs-organization`, `adr`) and six explicit slash commands
(`/docs-init`, `/docs-audit`, `/docs-update`, `/diagram-test`,
`/adr-new`, `/adr-review`). The installable surface lives under
`module/`. The root `Taskfile.yml` drives the quality gates: structural
and content lint, diagram lint, and the bash, node, bats, Venom, and
sandboxed-install suites.

## Repo layout

| Path | What it is |
| --- | --- |
| `module/AGENTS.md` | Lola module manifest (injected into the host's AGENTS.md / CLAUDE.md at install time) |
| `module/skills/docs-organization/SKILL.md` | Skill prompt — invariants, drift detection, diagram authoring |
| `module/skills/docs-organization/scripts/` | `check-structure.sh`, `check-staleness.sh`, `check-prose.mjs`, `check-refs.mjs`, `lint-mermaid.mjs`, `apply-palette.mjs`, `validate-palette.mjs`, `swap-palette.sh`, `contrast.mjs`, and `vendor/` |
| `module/skills/docs-organization/reference/` | `mermaid-house-style.md`, `readme-template.md`, `docs-tree-template.md`, palette assets |
| `module/skills/adr/SKILL.md` | Skill prompt — MADR 4.0 workflow, status transitions |
| `module/skills/adr/scripts/adr-index.sh` | Regenerates `index.md` whenever a new ADR is added or its status changes |
| `module/skills/adr/reference/` | `madr-template.md`, `review-rubric.md` |
| `module/commands/{docs-init,docs-audit,docs-update,diagram-test,adr-new,adr-review}.md` | The six slash commands |
| `Taskfile.yml` + `.taskfiles/scripts/` | Task automation and the shared quality-gate scripts |
| `tests/` | Structural-linter fixtures and bats suites, mermaid fixtures, Venom e2e |
| `docs/dev/architecture.md` | How the skills and gates work internally |
| `eval/` | Headless `/docs-audit` lane evaluation (maintainer research; not installed, not in `task test`). See `eval/README.md`. |
| `.github/workflows/` | CI and release |

## Working with this module

- **The module ships two skills, six commands, no autonomous behavior.**
  Every action requires an explicit `/...` invocation. Both skill
  descriptions carry the `DO NOT AUTO-INVOKE.` prefix. Do not add
  auto-trigger keywords to either one.
- **The slash commands activate the skill, then use `$SKILL_DIR`.**
  Each command file invokes the relevant skill via the host's Skill
  tool. The skill's SKILL.md defines `$SKILL_DIR` (the directory the
  host loaded it from). Reuse `$SKILL_DIR` for every `scripts/...` /
  `reference/...` reference — do not hardcode `.claude/skills/...` or
  search candidate paths. `docs/dev/architecture.md` explains why.

## Install via lola

This repo does not wrap `lola`. Install and uninstall are documented in the
README as raw `lola` commands, because lola already owns scope selection,
assistant targeting, and force prompts — wrapping it here would shadow that
flag surface and drift the moment lola adds a flag.

End users need no prerequisites at all: the skill's two npm dependencies ship
pre-bundled under `scripts/vendor/`, so a fresh install works offline with no
follow-up step.

`task vendor` is the contributor-only path — it installs the build toolchain
and regenerates those bundles. Run it after any dependency bump, and commit the
result: CI reruns it and fails on a non-empty `git diff vendor/`.

`task clean` removes derived state (`.test-output/` and `node_modules/`). It
deliberately leaves `vendor/` alone — those bundles are committed source of
record that ships to users, not scratch.

`.lola/`, `.claude/`, `.opencode/`, `.cursor/`, `.gemini/`, `.openclaw/`,
`/CLAUDE.md`, and `/GEMINI.md` are gitignored — they are install destinations
that land in the working tree during local install testing.

## Testing

```bash
task check              # every gate — this is the bar
task lint               # structural lint of module/
task lint:content       # skillsaw --strict
task lint:diagrams      # mermaid lint of the module's own docs
task test               # all suites
task test:unit          # node:test, beside the scripts
task test:bash          # bash script tests
task test:gates         # bats, covering the shared lint and verify scripts
task test:install       # sandboxed lola install, both scopes, claude-code + opencode
task test:e2e           # Venom
task test:diagrams      # lint + render every mermaid fixture
task cleanroom          # install verify inside a fresh UBI10 container
```

Add `MODE=llm` to any gate for errors-only output.

Nothing is done until `task check` is green.

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
- The four palette names + the palette-class naming (`sysA`…`sysF`,
  `edgeLabel`) — every diagram in every project that uses the module
  references them by name.
