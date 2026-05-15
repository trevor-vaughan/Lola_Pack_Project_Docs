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

### Locate the docs-organization skill bundle

Before running any script or reading any reference file shipped with the
docs-organization skill, locate the skill bundle on disk by checking these
locations in order and using the first that exists:

1. **Project-local skills directory** for your agent host
   (e.g., `.claude/skills/docs-organization/` under Claude Code, or the
   equivalent project-scoped skills path for your host).
2. **User-global skills directory** for your agent host
   (e.g., `~/.claude/skills/docs-organization/` under Claude Code,
   `~/.config/opencode/skills/docs-organization/` under OpenCode, or
   wherever your host installs user-scoped skill packs).
3. **Plugin-bundled location**, if your host installs skills as part of a
   plugin pack (e.g., `~/.claude/plugins/*/skills/docs-organization/`).
4. **Dev-workspace fallback**: `module/skills/docs-organization/` — this
   only resolves when running inside the pack's own source repository.

Use the agent host's filesystem tools (e.g., `Glob`, or `bash` for `ls`)
to check each candidate. Bind the first existing path to `$SKILL_DIR`.
If more than one candidate exists, prefer the most recently modified — if
that's ambiguous, ask the user which to use. Every `scripts/...` and
`reference/...` path below is relative to `$SKILL_DIR`.

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
