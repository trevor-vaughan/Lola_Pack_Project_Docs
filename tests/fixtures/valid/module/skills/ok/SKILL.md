---
name: ok
description: Use when verifying that the structural linter accepts a well-formed, auto-invoked skill with complete frontmatter.
---

# A valid fixture skill

This skill exists only to exercise `.taskfiles/scripts/lint-structure.sh` against a
correctly structured skill: it opens with `---` frontmatter, declares a
`description`, and has a real, complete body with no placeholder text.

## Why this matters

The linter must accept modules like this one without complaint, so that a
passing test run proves the "valid" path stays valid as the linter grows.
