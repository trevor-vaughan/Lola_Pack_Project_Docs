---
name: docs-organization
description: Use ONLY when the user explicitly invokes /docs-init, /docs-audit, /docs-update, or /diagram-test. Not triggered by conversation about documentation, README files, docs structure, or diagrams.
---

# docs-organization

> **Helper paths.** Every `scripts/<x>` and `reference/<x>` reference in this
> file is relative to the directory that contains this `SKILL.md`. Anchor on
> the loaded path (`SKILL_DIR=$(dirname "$(realpath <skill-md>)")`) and
> resolve every helper as `"$SKILL_DIR/scripts/<x>"` or
> `"$SKILL_DIR/reference/<x>"`. Do not hardcode `.claude/skills/...` or
> search candidate paths — the install destination varies by host and scope,
> but helpers are always next to the loaded `SKILL.md`.

This skill keeps a project's documentation organized and current. It is
**never auto-invoked**. All behavior is reached through one of four slash
commands:

- `/docs-init` — bootstrap or extend project doc structure
- `/docs-audit` — find drift between code and docs (read-only)
- `/docs-update` — apply fixes for drift findings
- `/diagram-test` — lint every mermaid diagram

## Invariants this skill enforces

1. **README.md is always self-sufficient.** Even after detailed usage docs
   move to `docs/usage/`, the README must provide enough Install +
   Quickstart for a new user to get started.
2. **`docs/superpowers/` is never committed.** It contains specs and plans
   that are working artifacts, not project deliverables. Enforced via
   `.gitignore` and via `check-structure.sh`'s `SUPERPOWERS_IN_GIT` check.
3. **Developer docs live under `docs/dev/`** when a project has them.
   `docs/dev/adr/` (or `docs/adr/` for legacy layouts) holds ADRs.
4. **Every mermaid diagram passes the house-style lint:** init header
   present, classDef names in the approved palette, text/fill contrast
   ≥ 4.5:1 (AA) and fill/background contrast ≥ 3.0:1 (graphical objects)
   for both light and dark reference backgrounds.

## Scope of audit

The skill audits **project-centric documentation only** — content that
describes the project itself. When enumerating documentation files (in
`/docs-audit` and any command that re-runs its lanes), include:

- `README.md` at the repository root.
- Every `.md` under `docs/`.
- For skill-pack repositories: every `.md` under `module/` that ships as
  part of the pack (`module/skills/*/SKILL.md`, `module/commands/*.md`,
  `module/skills/*/reference/*.md`).

**Exclude unconditionally:**

- Any path matched by `.gitignore` (e.g., `docs/superpowers/`,
  `node_modules/`, build artifacts).
- Any directory whose name starts with `.`. These are tool/agent-runtime
  spaces (`.git/`, `.claude/`, `.opencode/`, `.lola/`, `.gemini/`,
  `.cursor/`) and never contain project documentation. A single
  structural rule covers existing and future agent hosts without an
  enumerated allowlist.
- LLM-configuration files at any level: `CLAUDE.md`, `AGENTS.md`,
  `GEMINI.md`, `.cursorrules`. These describe agent behavior; they drift
  with prompt-engineering iteration rather than with code, so auditing
  them for code drift produces noise.

**Tooling preference:** when enumerating files, prefer the agent host's
built-in glob/search tools (e.g., Claude Code's `Glob` and `Grep`) over
shell `find` / `grep`. Built-ins are faster, portable across platforms,
and return structured output without shell-escaping concerns. Shell
tools are still appropriate for the deterministic scripts under
`scripts/`, which run outside the agent.

## When a diagram earns its place

This skill nudges authors toward diagrams, but applies a strict bar.
A `MISSING_DIAGRAM` finding fires only when **both** are true:

1. The relationships are non-obvious from a linear top-to-bottom read —
   real branching, parallelism, state transitions, or non-trivial
   component interactions — not a sequential procedure with at most one
   binary branch.
2. A reader would have to mentally render a diagram anyway to follow
   the prose.

Reject candidates that already read as a diagram in text form
(directory trees, numbered install steps), small matrices better served
by a table, three-item role lists framed as "pipelines", and meta-loops
whose value is conceptual rather than informational. The
`reference/mermaid-house-style.md` "Skip the diagram for" rule is the
sibling test — apply it strictly.

The full concept-to-diagram-type table (with rationale for each
pairing) and the skip rule live in `reference/mermaid-house-style.md`.
Consult it when emitting `MISSING_DIAGRAM` findings or when scaffolding
a starter block. `/docs-update` offers to scaffold a starter mermaid
block only for findings that clear the bar. Findings are info-level —
never blockers. Authors are nudged, not forced.

## Tools this skill uses

All scripts return JSON to stdout. Each script's exit code:
0 = no findings, 1 = findings, 2 = internal error.

- `scripts/check-structure.sh` — file presence, `.gitignore`, ADR index.
- `scripts/check-staleness.sh` — git log delta between docs and source.
- `scripts/lint-mermaid.mjs` — merval parse, init header, palette,
  contrast.

Requires Node.js ≥20 and one npm dep (`@aj-archipelago/merval`).

**First-run setup after `lola install`.** lola installs the pack files but
does not run `npm install`. The first invocation of `/diagram-test` after
a fresh pack install will emit a `MERVAL_NOT_INSTALLED` blocker finding
that names the exact directory and command needed. Surface the finding's
message verbatim to the user — it tells them precisely what to run.

For pack developers, `task install` runs both the lola install and the
npm install in one step.

## References

- `reference/mermaid-house-style.md` — palette, init header, examples,
  and **merval syntax constraints** (the strict-subset gotchas every
  diagram in this project must follow; consult before scaffolding).
- `reference/readme-template.md` — minimum acceptable README structure.
- `reference/docs-tree-template.md` — `docs/dev/` scaffold.

## Cross-skill

This skill does not touch ADRs directly. The companion `adr` skill (same
pack) owns `docs/dev/adr/` content via `/adr-new` and `/adr-review`. The
two skills share knowledge of the `docs/` layout but have separate
responsibilities.
