# Changelog

All notable changes to this module are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **The skill's npm dependencies now ship with it.** `@aj-archipelago/merval`
  and `markdown-it` are vendored as pre-built bundles under
  `module/skills/docs-organization/scripts/vendor/` (330K, both MIT). Installing
  the module is now two `lola` commands with no prerequisites — no `npm
  install`, no network, no follow-up step.
- `task vendor` rebuilds those bundles from the versions `package.json` pins,
  and CI fails if a committed bundle has drifted from them.
- Sandboxed install verification (`task test:install`), covering both scopes and
  both `claude-code` and `opencode`. It redirects `HOME` and `LOLA_HOME` into a
  temporary directory, so it runs locally without touching a real assistant
  install. It asserts that every file a skill ships actually arrives, which is
  what would catch a future lola filtering `vendor/` out in transit.
- `task check` as the single gate: structural lint, content lint, diagram lint,
  and every test suite.
- `task cleanroom` repeats the install verification inside a fresh UBI10
  container.
- MegaLinter in CI (markdownlint, yamllint, shellcheck, betterleaks, trivy,
  secretlint) and the skillsaw content gate (`task lint:content`).
- Dependabot for GitHub Actions, the `Containerfile`, and the pinned `merval`
  and `markdown-it` dependencies.
- Tag-triggered GitHub releases.
- `docs/dev/architecture.md`, the maintainer-facing companion to `AGENTS.md`.
- `MODE=llm` on the lint and verify gates for errors-only output.

### Changed

- **BREAKING:** `task lint` now runs the structural module lint. The mermaid
  diagram linter moved to `task lint:diagrams`.
- **BREAKING:** `task install`, `task uninstall`, and their subtargets are
  removed. lola owns installation; the README documents `lola mod add` and
  `lola install` directly. `install:scripts` becomes `task vendor`, and
  `uninstall:scripts` folds into `task clean`, which now removes every derived
  artifact — but never `vendor/`, which is committed and shipped.
- `@aj-archipelago/merval` and `markdown-it` moved from `dependencies` to
  `devDependencies`. They are build inputs for the vendored bundles now, not
  runtime imports.
- `scripts/` moved to `.taskfiles/scripts/`. `scripts/lint-module.sh` is
  replaced by the shared `lint-structure.sh`.
- Both skill descriptions now carry the `DO NOT AUTO-INVOKE.` prefix, matching
  the convention other lola modules use and letting the structural linter
  verify that each explicit skill is reachable from a command.
- Documentation says "module" rather than "pack", and links to
  <https://lobstertrap.org/lola/>.

### Fixed

- `README.md` and `AGENTS.md` described a `.taskfiles/` directory that did not
  exist, and described `tests/` as holding unit tests that actually live beside
  the scripts they cover.
- CI asserted opencode installs at `~/.opencode/`, a path lola moved to
  `~/.config/opencode/`.

### Removed

- The `MERVAL_NOT_INSTALLED` finding, its detection branch, and its two test
  cases. It reported that the mermaid linter's dependency was absent from an
  installed skill; with dependencies vendored, that state cannot occur.
