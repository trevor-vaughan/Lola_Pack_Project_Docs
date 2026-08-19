---
name: y
description: Use when verifying that the structural linter rejects a skill that ships a helper file it never teaches the host to locate.
---

# A fixture skill that ships an unanchored helper

This skill ships `helper.sh` beside this file — at depth 1, not tucked into a
`scripts/` subdirectory — and never tells the host how to resolve its own
directory. A host that cannot resolve the path will guess at it, so the
linter must reject this shape.
