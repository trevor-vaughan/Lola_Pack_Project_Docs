---
description: Lint every mermaid diagram in the project — syntax, house-style header, palette, contrast
argument-hint: "[paths...]"
---

# /diagram-test

Validate mermaid diagrams. Walks the project (or the given paths) and runs
the lint checks documented in the docs-organization skill's mermaid
house-style reference.

## User-provided arguments

> $ARGUMENTS

## Instructions

### Activate the docs-organization skill

Invoke the `docs-organization` skill via your host's Skill tool. The skill's
`SKILL.md` defines `$SKILL_DIR` as the directory the host loaded it from
(`SKILL_DIR=$(dirname "$(realpath <loaded-skill-md>)")`). Reuse `$SKILL_DIR`
for every `scripts/...` and `reference/...` reference below — do not
hardcode `.claude/skills/...` or search candidate paths.

### Steps

1. Read `$SKILL_DIR/SKILL.md` for the invariants and principles this skill enforces. The procedure below is the source of truth for what to do.
2. Determine targets:
   - If `$ARGUMENTS` is non-empty, use those paths.
   - Otherwise, lint `README.md` and everything under `docs/` (except
     `docs/superpowers/`).
3. Run `node $SKILL_DIR/scripts/lint-mermaid.mjs --json <targets>`. The
   `--json` flag returns structured output for parsing; without it, the
   script emits a human-readable text report (useful when the user is
   running the script directly, but harder to parse here).
4. Parse the JSON output. Render findings to the user grouped by file,
   showing the rule code, message, and (where applicable) the line number
   from the source.
5. **Do not auto-fix.** Suggest /docs-update for fixable findings (missing
   house-style header, unapproved classname when the user wants the palette
   colors); manual fix for contrast and syntax errors.

### Optional rendering

If the user asks for visual proof (e.g., "render and show me these
diagrams"), use `mmdc` (the mermaid CLI) to produce PNGs. **Always pass
`--cssFile $SKILL_DIR/reference/palettes/er-overrides.css`** — this CSS
overrides mermaid's hardcoded `rgba(0,0,0,0.5)` label background that
otherwise makes ER edge labels invisible on dark page backgrounds. Render
against both `white` and `#1e1e1e` for any palette except Parchment
(light-bg only):

```
mmdc -i <file>.mmd -o <file>.light.png -b white --cssFile $SKILL_DIR/reference/palettes/er-overrides.css
mmdc -i <file>.mmd -o <file>.dark.png  -b "#1e1e1e" --cssFile $SKILL_DIR/reference/palettes/er-overrides.css
```

The four palette JSONs live at `$SKILL_DIR/reference/palettes/{solar,
federation,citrus,parchment}.json` for reference.

## Stop conditions

- If the script exits 2 (internal error): surface the error.
- If a finding has code `MERVAL_NOT_INSTALLED`: surface the finding's
  message verbatim (it includes the exact `npm install` command and
  the directory to run it in). The user needs to install the npm
  dependency before /diagram-test can do anything useful — this
  typically happens once after a fresh `lola install` of the pack.
