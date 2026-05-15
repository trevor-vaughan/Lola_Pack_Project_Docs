# docs-discipline

A lola pack with two skills for keeping technical project documentation on
track, current, and consistent. Nothing in this pack auto-invokes — every
behavior is reached through an explicit slash command.

## When to use this pack

- **Starting a new project:** `/docs-init` scaffolds README, docs/dev/, and
  the `.gitignore` entry for `docs/superpowers/`.
- **Catching drift:** `/docs-audit` (read-only) surfaces structural,
  staleness, and content drift. `/docs-update` applies fixes
  interactively.
- **Authoring diagrams:** `/diagram-test` validates every mermaid diagram
  against the house style (syntax, init header, palette, contrast). Four
  contrast-validated palettes ship with the skill — Solar (default),
  Federation, Citrus, Parchment. `task render -- file.mmd` renders any
  diagram with the skill's CSS overrides applied; `task palette -- name
  file.mmd` swaps a diagram to a different palette.
- **Recording decisions:** `/adr-new <title>` drafts an MADR-format
  Architectural Decision Record. `/adr-review <NNNN>` runs an
  independent rubric pass via a context-isolated subagent.

## Two skills in this pack

- **docs-organization** — README and `docs/` layout, drift detection,
  mermaid authoring and testing. See `skills/docs-organization/SKILL.md`.
- **adr** — ADR lifecycle, MADR 4.0 template, review rubric. See
  `skills/adr/SKILL.md`.

The skills are independent. Use one without the other if you prefer.

## Conventions this pack enforces

1. Top-level `README.md` is always self-sufficient for basic user
   onboarding.
2. Developer documentation lives under `docs/dev/`.
3. `docs/superpowers/` is in `.gitignore` and never committed.
4. ADRs live in `docs/dev/adr/` (or `docs/adr/` for legacy layouts).
5. Every mermaid diagram begins with the required `%%{init}%%` header
   from one of the four shipped palettes (Solar is the default) and uses
   palette classes (`sysA` … `sysF`, `edgeLabel`) with WCAG-verified
   contrast.

## Requirements

- Git (the pack assumes you are operating in a git repository).
- Node.js ≥20 for the mermaid linter.
- Bash for the structure/staleness/index scripts.
