---
name: bad
description: Use when verifying that the structural linter rejects a skill whose frontmatter block is never closed.

# A fixture skill with unclosed frontmatter

The opening `---` above is never matched by a closing `---`, so the whole
file reads as one runaway frontmatter block. It exists to exercise the
linter's "no closing ---" failure path.
