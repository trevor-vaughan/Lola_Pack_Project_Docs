## Pack development notes

`Taskfile.yml` is for pack developers self-testing the pack live in their
own AI assistant. End users install via `lola install` directly and do not
need it.

- **`task install` ordering is load-bearing.** `install:scripts` must run
  *before* `install:lola`. `lola install` copies
  `module/skills/docs-organization/scripts/` verbatim into the assistant's
  skill directory, so `node_modules` must exist in the source for the
  installed location to be runnable. Reversing the order leaves dev
  self-tests missing merval — silently, with no error from `task` itself.
  End-user installs via `lola install` directly are *expected* to hit
  `MERVAL_NOT_INSTALLED` on first `/diagram-test`; dev self-tests are not.
- **`SCOPE`** (`user` default, also accepts `project`) controls
  `lola install --scope`. `task uninstall` ignores it — `lola mod rm -f`
  is a total teardown across every scope plus registry deregistration.

## Lola Skills

These skills are installed by Lola and provide specialized capabilities.
When a task matches a skill's description, read the skill's SKILL.md file
to learn the detailed instructions and workflows.

**How to use skills:**
1. Check if your task matches any skill description below
2. Use `read_file` to read the skill's SKILL.md for detailed instructions
3. Follow the instructions in the SKILL.md file

<!-- lola:skills:start -->
<!-- lola:skills:end -->

<!-- lola:instructions:start -->
<!-- lola:module:docs-discipline:start -->
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
  against the house style (syntax, init header, palette, contrast).
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
5. Every mermaid diagram begins with the required `%%{init}%%` header and
   uses palette classes (`sysA` … `sysF`, `edgeLabel`) with WCAG-verified
   contrast.

## Requirements

- Git (the pack assumes you are operating in a git repository).
- Node.js ≥20 for the mermaid linter.
- Bash for the structure/staleness/index scripts.
<!-- lola:module:docs-discipline:end -->
<!-- lola:instructions:end -->
