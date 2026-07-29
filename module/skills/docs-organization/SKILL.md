---
name: docs-organization
description: DO NOT AUTO-INVOKE. Use ONLY when the user explicitly invokes /docs-init, /docs-audit, /docs-update, or /diagram-test. Not triggered by conversation about documentation, README files, docs structure, or diagrams.
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
- For lola module repositories: every `.md` under `module/` that ships as
  part of the module (`module/skills/*/SKILL.md`, `module/commands/*.md`,
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

A **hero demo** (`MISSING_DEMO`) is the demo-recording sibling of the diagram
nudge, on the same strict-bar/encouragement contract. It fires only for a
README/landing page of a **user-facing, runnable tool** (CLI, TUI, app) that does
not already show itself in action (no GIF, screenshot, asciinema, or linked
screencast) — never for a library (its demo is a code snippet), a spec, or a
maintainer doc, and at most once per repo (the hero slot). Because an LLM cannot
record a screencast, `/docs-update` drops an **HTML-comment spec** at the hero
slot — the command sequence to record, what the viewer should see, and a suggested
tool (asciinema / VHS) — never a fabricated artifact. (Validated 25/25 on eval
fixtures.)

## Tools this skill uses

All scripts return JSON to stdout. Each script's exit code:
0 = no findings, 1 = findings, 2 = internal error.

- `scripts/check-structure.sh` — file presence, `.gitignore`, ADR index.
- `scripts/check-staleness.sh` — git log delta between docs and source.
- `scripts/check-prose.mjs` — readability and size over a markdown AST:
  `WALL_OF_TEXT` (dense top-level paragraph), `DENSE_BULLET` (fat flat list
  item with no sub-bullets), `SPLIT_CANDIDATE` (oversized file or H2 section).
- `scripts/check-refs.mjs` — reference integrity: `REF_BROKEN` /
  `REF_NOT_IN_GIT` (a markdown link to a path that does not resolve to a
  git-tracked file) and `UNLINKED_REF` (a `§` section citation with no link).
- `scripts/lint-mermaid.mjs` — merval parse, init header, palette,
  contrast.

Requires Node.js ≥20 and two npm deps (`@aj-archipelago/merval`,
`markdown-it`).

### Deterministic where it's unambiguous, LLM where it's fuzzy

Size is mechanical, so `check-prose.mjs` owns enumeration (`WALL_OF_TEXT`,
`DENSE_BULLET`, `SPLIT_CANDIDATE`) and repeats it identically every run; an LLM
asked to enumerate under-reports on long files. The LLM lane adjudicates only
the candidates the script surfaces: choppy rhythm, and dense-prose *genres*
(academic, legal, formal spec) where `WALL_OF_TEXT` should be suppressed. A
procedure spread across many small blocks trips no size check but is
absence-of-structure, so it belongs to the grounded `NEEDS_STRUCTURE` sub-check
in Lane 5.

Why each signal sits where it does:
`$SKILL_DIR/reference/deterministic-vs-llm.md`.

### References should be followable

A reference the reader cannot follow is a defect, and much of it is
deterministic: `check-refs.mjs` resolves every markdown *link* against the
git-tracked file set. A link to a missing path (`REF_BROKEN`) or to a real but
gitignored/unstaged file (`REF_NOT_IN_GIT`) dangles for anyone who clones. It
also surfaces `§` section citations that carry no link (`UNLINKED_REF`) — a
cheap tell for a prose reference (often to an internal spec) the reader can't
follow. The rule is "a reference should be followable", not "everything
referenced must be committed": some references are legitimately private or
external, so the script only surfaces danglers and the author resolves them in
`/docs-update` (link, commit, or mark external — never strip a `§` citation).
Inline-code mentions of source paths are intentionally *not* resolved — they are
repo-root-relative and full of placeholders, so a heuristic there is mostly
false positives.

### Ground the review in Diátaxis, then cold-read it

Three LLM lanes judge a document by what it is *for*. A **grounding** pass
classifies the file's [Diátaxis](https://diataxis.fr) mode (`tutorial`,
`how-to`, `reference`, `explanation`, or `landing`) plus audience and
reader-goal, threads that into the other prompts, and emits `MODE_MIXING` when
a non-`landing` doc embeds a mode that interrupts its job. The **cold read**
reads the doc as its intended audience and flags where a real reader gets
stuck. The **completeness** check (`INCOMPLETE_FOR_TYPE`) asks whether a reader
of that type would be blocked by something the doc omits. All three are
info-level: the framework guides, it does not dictate.

Why each lane is shaped that way, what it measured on the eval fixtures, and
the guards that keep it from nagging:
`$SKILL_DIR/reference/diataxis-grounding.md`.

### Never read an empty LLM lane as "clean"

The content-drift and missing-diagram lanes are irreducibly LLM-driven. Their
main consistency risk is not partial recall — measured with a headless harness,
whole-file content-drift finds every planted drift through several hundred lines
— but a *transient empty reply* (~1 run in 5) that reads as a spurious all-clear.
The command procedure therefore validates every subagent reply, retries an
empty/errored one up to twice, and records a `LANE_FAILED` **Warning** if it
still yields nothing. An unaudited file is "unknown", never "clean".

## References

- `reference/mermaid-house-style.md` — palette, init header, examples,
  and **merval syntax constraints** (the strict-subset gotchas every
  diagram in this project must follow; consult before scaffolding).
- `reference/diataxis-grounding.md` — why the grounding, cold-read, and
  completeness lanes are shaped as they are, and what each measured.
- `reference/deterministic-vs-llm.md` — why each readability signal is owned
  by `check-prose.mjs` or by an LLM lane, and the guards on each.
- `reference/readme-template.md` — minimum acceptable README structure.
- `reference/docs-tree-template.md` — `docs/dev/` scaffold.

## Cross-skill

This skill does not touch ADRs directly. The companion `adr` skill (same
module) owns `docs/dev/adr/` content via `/adr-new` and `/adr-review`.
The two skills share knowledge of the `docs/` layout but have separate
responsibilities.
