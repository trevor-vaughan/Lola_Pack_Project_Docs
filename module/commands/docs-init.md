---
description: Bootstrap or extend project documentation structure (README, docs/, .gitignore)
argument-hint: ""
---

# /docs-init

Scaffold a project's documentation structure following the docs-organization
skill's conventions. Idempotent — safe to run on an existing project; will
not overwrite files that already have content.

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
2. Detect current state:
   - Does `README.md` exist? Is it non-empty?
   - Does `docs/` exist? Is `docs/dev/` populated?
   - Does `.gitignore` contain `docs/superpowers/`?
3. **Greenfield path** (no README, no docs/):
   - Read `$SKILL_DIR/reference/readme-template.md`.
     Write `README.md` using that template, filling project name from the
     repo's directory name and asking the user one question for the
     one-sentence description.
   - Read `$SKILL_DIR/reference/docs-tree-template.md`.
     Create `docs/dev/README.md`, `docs/dev/architecture.md`,
     `docs/dev/contributing.md` with their template contents. The
     `architecture.md` template includes a starter mermaid block so authors
     have a visible nudge to keep the diagram current. Do not create
     `docs/usage/` — it appears later when /docs-audit recommends a split.
   - Create `docs/dev/diagrams/` containing a `README.md` with this content:

     ```markdown
     # Diagrams

     `.mmd` files referenced from `docs/dev/*.md`. See the
     docs-organization skill's mermaid house-style reference for when to
     add a diagram and how to style it.
     ```

     Diagrams are actively encouraged for architecture overviews,
     sequence flows, state machines, decision trees, and data flow.
4. **Existing-project path** (README exists, docs/ may or may not):
   - Read the current README. If it contains substantial usage detail
     (heuristic: more than 200 lines, or sections labeled "Configuration",
     "Advanced usage", "API reference"), ask the user: "Your README is
     dense. Keep it self-sufficient (no migration), or split detailed
     sections into docs/usage/ now?" Wait for the answer before proceeding.
   - If `docs/dev/` is missing, create it from the template.
   - Never overwrite an existing file with non-empty content. If a file
     exists but is empty, the template content is acceptable.
5. **Always:**
   - Append `docs/superpowers/` to `.gitignore` if not present (preserve
     existing entries).
   - Run `bash $SKILL_DIR/scripts/check-structure.sh`
     to verify the structural invariants now hold. Surface any remaining
     findings.
6. Commit the scaffolding with a conventional message: `docs: scaffold
   documentation structure`.

## Stop conditions

- If the project is not a git repo: print a warning and exit without
  writing. The skill assumes git is in use.
- If the user declines a destructive prompt (e.g., refuses the README
  split), apply only the non-destructive changes (.gitignore, missing
  docs/dev/ files).
