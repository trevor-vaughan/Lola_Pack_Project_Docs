---
description: Use when verifying that the structural linter rejects a skill whose frontmatter omits the name field.
---

# A fixture skill with no name

This skill's frontmatter closes properly and carries a `description:`, but
deliberately omits `name:`, which `.taskfiles/scripts/lint-structure.sh`
requires. It exists to exercise the linter's "missing name" failure path.
