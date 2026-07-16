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

## Notes for AI assistants

Each skill's `SKILL.md` carries a "Helper paths" preamble instructing the
agent to anchor on the loaded SKILL.md path
(`SKILL_DIR=$(dirname "$(realpath <skill-md>)")`) and reference every
`scripts/<x>` and `reference/<x>` helper as `"$SKILL_DIR/..."`. The slash
commands (`/docs-init`, `/docs-audit`, `/docs-update`, `/diagram-test`,
`/adr-new`, `/adr-review`) each activate the relevant skill via the
host's Skill tool and reuse `$SKILL_DIR` from there. Do not hardcode
`.claude/skills/...` or search candidate paths — the install destination
varies by host (Claude Code, OpenCode, Cursor, Gemini CLI) and scope, but
helpers are always next to the loaded `SKILL.md`.

When `/docs-update` triggers a `MISSING_ADR_INDEX` finding, it
additionally activates the `adr` skill and binds `$ADR_DIR` from its
loaded `SKILL.md` location the same way.

## House voice (for maintainers and AI assistants editing these docs)

These docs are edited by AI assistants. Left unchecked, generated prose drifts
toward a recognizable register. Hold the line on the following.

**Show, don't tell.** A worked example beats a description. If a command
produces output, show a realistic sample of it. If a template gets filled in,
ship one filled-in example, not just the blank.

**Readability — the "four ideas" test.** A paragraph that enumerates several
mechanisms or rules forces the reader to hold them all at once. Break it into
sub-bullets, or add vertical whitespace at the topic seams, so the eye lands on
one beat at a time. This is broader than whitespace-only reflow — restructuring
into bullets is expected when a paragraph lists several distinct points.

**Cut the tells.** Prefer plain verbs and concrete nouns. Watch for and remove:
- Booster adverbs and brochure verbs: "actively", "simply", "seamlessly",
  "leverage", "robust", "comprehensive", "powerful", "effortlessly".
- Formulaic scaffolds: "It's worth noting that…", "In order to…" (use "to"),
  "X — but only when Y" as a section title.
- Uniform rhythm: several same-length sentences in a row, or an em-dash in
  every sentence. Vary it.

**Never touch on a voice edit:** technical claims, code blocks, commands, file
paths, exact finding codes, and error strings. Voice work changes register and
rhythm, not facts. When in doubt, preserve verbatim.

## Exemplars & references

Reference material for future refinement — patterns worth borrowing, not text
worth copying. Cite the idea in your own words. External links rot; re-check
them when you touch this section.

- [MADR](https://adr.github.io/madr/) — the decision-record template `/adr-new`
  instantiates; the canonical shape for "Considered Options" and "Consequences".
- [Nygard, "Documenting Architecture Decisions"](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
  — why lightweight, per-decision records beat a monolithic design doc.
- [Diátaxis](https://diataxis.fr/) — the four-mode model (tutorial / how-to /
  reference / explanation) behind keeping the README task-focused and pushing
  architecture into `docs/dev/`.
- [Write the Docs](https://www.writethedocs.org/) — a working community's
  conventions for docs that stay maintained.
- [Mermaid](https://mermaid.js.org/) — full diagram grammar; the house style is
  a strict subset (see the mermaid house-style reference).
- [lola](https://docs.getlola.dev/) — the cross-host pack format this ships as.
