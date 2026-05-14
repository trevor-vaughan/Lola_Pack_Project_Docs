# docs-discipline

> A lola pack with two skills for keeping technical project documentation
> on track, current, and consistent — via explicit slash commands only.

## What this is

`docs-discipline` is a lola pack
([LobsterTrap/lola](https://github.com/LobsterTrap/lola)) that ships two
independent skills for AI coding assistants:

- **docs-organization** — manages README and `docs/` layout, detects drift
  between code and documentation, validates mermaid diagrams against a
  house style (palette + WCAG contrast).
- **adr** — manages Architectural Decision Records (MADR 4.0) with an
  inline self-review pass on creation and a context-isolated subagent
  review pass on demand.

Nothing in this pack auto-invokes. The skills are reached only through six
explicit slash commands: `/docs-init`, `/docs-audit`, `/docs-update`,
`/diagram-test`, `/adr-new`, `/adr-review`.

## Install

```bash
# As a lola pack:
lola mod add github.com/<owner>/<repo>
lola install docs-discipline
```

Requirements: git, Node.js ≥20, bash, lola.

The first time you run `/diagram-test` after install, the linter will
detect that its npm dependency (`@aj-archipelago/merval`) isn't installed
and report a `MERVAL_NOT_INSTALLED` finding with the exact path and
command needed (a one-time `cd <skills-dir> && npm install`).

## Quickstart

In a project that already has the pack installed:

```bash
# Bootstrap the documentation structure for a new project:
/docs-init

# At any point, find drift between code and docs:
/docs-audit

# Apply fixes interactively:
/docs-update

# Validate diagrams:
/diagram-test

# Record an architectural decision:
/adr-new "Use Postgres for primary storage"

# Run an independent review of an existing ADR:
/adr-review 0001
```

## Where to go next

- **For maintainers/contributors:** `docs/dev/` (scaffold it by running
  `/docs-init` against this repo).
- **For the lola pack format:** see https://lobstertrap.org/lola/
- **For MADR:** see https://adr.github.io/madr/

## Conventions enforced

1. Top-level `README.md` always self-sufficient for basic user onboarding.
2. Developer documentation under `docs/dev/`.
3. `docs/superpowers/` is in `.gitignore` and never committed.
4. ADRs in `docs/dev/adr/` (or `docs/adr/` for legacy layouts).
5. Every mermaid diagram begins with the house-style init header and uses
   palette classes with WCAG-verified contrast.

## License

(set when publishing)
