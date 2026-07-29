---
name: bad
---

# A fixture skill with no description

This skill's frontmatter has an opening and closing `---` delimiter but
deliberately omits the `description:` field, which `.taskfiles/scripts/lint-structure.sh`
requires. It exists to exercise the linter's "missing description" failure
path.
