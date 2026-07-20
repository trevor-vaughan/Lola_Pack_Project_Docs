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

Size is a mechanical property: a paragraph's *word count*, a bullet's word count,
a file's or section's *line span*. Those are exact and reproducible, so
`check-prose.mjs` triggers on them alone — reading the markdown-it AST (fenced
code, tables, blockquotes, and nested lists distinguished by node type, not
regex) and enumerating byte-identically every run. An LLM asked to *enumerate*
readability problems under-reports on long files (recall fades toward the end)
and two runs disagree, so enumeration is the script's job.

What the script deliberately does **not** do is count sentences. Sentence
segmentation is a genuinely hard NLP problem — abbreviations (`e.g.`, `i.e.`,
`vs.`), decimals, initials, ellipses — that no regex gets right; a sentence
counter false-flags abbreviation-heavy technical prose. So the fuzzy judgments
are deferred to the LLM lane, which only ever adjudicates the candidates the
script surfaces: is the rhythm choppy, and is this a dense-prose *genre*
(academic paper, legal text, formal spec) where a `WALL_OF_TEXT` finding should
be suppressed. Deterministic backbone; LLM for the judgment residue.

`DENSE_BULLET` exists because the wall-of-text rule deliberately excludes lists,
so a 150-word flat bullet slips past it. A bullet already broken into
sub-bullets is the desired shape and is never flagged, however long overall.

Every deterministic check above measures the size of a *single* block. The
complementary axis is a procedure spread across *many small* blocks — prose
interleaved with back-to-back command fences, no paragraph long enough to trip
`WALL_OF_TEXT`, no list to trip `DENSE_BULLET`, short enough to duck
`SPLIT_CANDIDATE` — yet with no list or sub-headings to give the eye a rest
point. That is absence-of-structure, not size, so it is judged by the grounded
`NEEDS_STRUCTURE` sub-check in Lane 5 rather than by `check-prose.mjs`. It fires
only on procedural runs (a command-by-command walkthrough, including a README
Install/Quickstart — this one is **not** landing-exempt), and never on
already-listed steps, a short one-or-two-command run, or non-procedural prose.
(Validated 25/25 on eval fixtures.)

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

Every LLM lane runs better knowing what the document is *for*. A one-line
grounding pass classifies the file's [Diátaxis](https://diataxis.fr) mode —
`tutorial`, `how-to`, `reference`, `explanation`, or `landing` (a README/entry
page, legitimately multi-mode) — plus audience and reader-goal, and threads it
into the content-drift, missing-diagram, cold-read, and structure prompts. The mode makes
the other lanes' judgments principled rather than ad hoc: dense unbroken prose
is a convention in `reference`/`explanation` but a defect in `tutorial`/`how-to`;
"would a reader get stuck" is a tutorial/how-to question, while `reference` is
judged on completeness. Grounding also emits `MODE_MIXING` (info) when a
non-`landing` doc commits to one mode but embeds another that interrupts its job
(a how-to that detours into pages of concept). It is a **lens, not a law**: a
`landing` page is never flagged for mixing, and the finding is info-level — the
framework guides, it does not dictate. (Validated: 5/5 consistent on eval
fixtures, correctly exempting the landing page.)

The **cold read** is the lane none of the narrow checks cover: read the doc as
the intended audience and flag where a real reader gets stuck — an undefined
term, a missing step, a dangling "see below", prose that contradicts its own
example, terminology that drifts, an unstated prerequisite, a spec citation the
reader can't resolve. Measured on the eval fixture it is high-precision (0
spurious findings, 4/5 planted traps caught), so its findings are treated as
real but kept info-level.

A companion **completeness** check (`INCOMPLETE_FOR_TYPE`) uses
[The Good Docs Project](https://www.thegooddocsproject.dev) notion of what each
Diátaxis type needs — a troubleshooting doc pairs every symptom with a
resolution, a reference describes every listed entry, a how-to names the
prerequisites its steps assume. It is **not** a section-checklist: it fires only
for a reader who would be *blocked*, never for a missing named heading, and
never on a `landing` page. That guard is load-bearing — without it the check
nagged even a complete how-to (0/5); with it, 20/20 on the eval (full recall on
real gaps, zero nagging on complete or intentionally-minimal docs).

### Never read an empty LLM lane as "clean"

The content-drift and missing-diagram lanes are irreducibly LLM-driven. Their
main consistency risk is not partial recall — measured with a headless harness,
whole-file content-drift finds every planted drift through several hundred lines
— but a *transient empty reply* (~1 run in 5) that reads as a spurious all-clear.
The command procedure therefore validates every subagent reply, retries an
empty/errored one up to twice, and records a `LANE_FAILED` **Warning** if it
still yields nothing. An unaudited file is "unknown", never "clean".

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
