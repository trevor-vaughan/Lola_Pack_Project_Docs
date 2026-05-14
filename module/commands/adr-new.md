---
description: Draft a new ADR with inline self-review, status proposed, MADR 4.0 template
argument-hint: "<decision title>"
---

# /adr-new

Draft a new Architectural Decision Record using the MADR 4.0 template.
Pulls context from the recent conversation; runs an inline self-review pass
before writing the file.

## User-provided arguments

> $ARGUMENTS

## Instructions

### Locate the adr skill bundle

Before running any script or reading any reference file shipped with the
adr skill, locate the skill bundle on disk by checking these locations
in order and using the first that exists:

1. **Project-local skills directory** for your agent host
   (e.g., `.claude/skills/adr/` under Claude Code, or the equivalent
   project-scoped skills path for your host).
2. **User-global skills directory** for your agent host
   (e.g., `~/.claude/skills/adr/` under Claude Code,
   `~/.config/opencode/skills/adr/` under OpenCode, or wherever your
   host installs user-scoped skill packs).
3. **Plugin-bundled location**, if your host installs skills as part of a
   plugin pack (e.g., `~/.claude/plugins/*/skills/adr/`).
4. **Dev-workspace fallback**: `module/skills/adr/` — this only resolves
   when running inside the pack's own source repository.

Use the agent host's filesystem tools (e.g., `Glob`, or `bash` for `ls`)
to check each candidate. Bind the first existing path to `$SKILL_DIR`.
If more than one candidate exists, prefer the most recently modified — if
that's ambiguous, ask the user which to use. Every `scripts/...` and
`reference/...` path below is relative to `$SKILL_DIR`.

### Steps

1. Read `$SKILL_DIR/SKILL.md` for the invariants and principles this skill enforces. The procedure below is the source of truth for what to do.
2. Resolve the ADR directory:
   - If `docs/dev/adr/` exists, use it.
   - Else if `docs/adr/` exists, use it.
   - Else create `docs/dev/adr/` (mirrors what /docs-init produces).
3. Allocate the next NNNN by listing files matching `[0-9][0-9][0-9][0-9]-*.md`
   in the resolved directory and incrementing. Zero-pad to four digits.
4. Read `$SKILL_DIR/reference/madr-template.md`. Draft an ADR using
   the user-supplied title and rationale pulled from the recent
   conversation context. Set `status: proposed` and today's date.
5. **Inline self-review (before writing the file):**
   - Scan for placeholders: any remaining `<...>` template marks, `TBD`,
     `TODO`. Fill them in or remove sections that don't apply.
   - Verify "Considered Options" has at least two non-chosen alternatives.
   - Verify "Consequences" has both positive AND negative items.
   - Verify "Decision Outcome" has a "because" clause that ties to a
     listed driver.
   - If any check fails, fix inline before writing.
6. Write the file. Run `bash $SKILL_DIR/scripts/adr-index.sh <adr-dir>`
   to regenerate the index.
7. Commit: `docs(adr): NNNN <title> (proposed)`.

## Stop conditions

- If the title is empty: ask the user for one.
- If the conversation context has no rationale: ask the user for the
  problem and constraints before drafting.
