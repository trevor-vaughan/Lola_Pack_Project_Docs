# docs-discipline internals

The maintainer-facing companion to the root `AGENTS.md`. Where `AGENTS.md` says
what to do, this says how the machinery works, so a future maintainer can
change it without breaking something subtle.

## Skill-relative helper paths

Both skills ship executable helpers next to their `SKILL.md`. The install
destination varies by host and scope — `~/.claude/skills/`,
`~/.config/opencode/skills/`, `<project>/.opencode/skills/`, and more — so no
helper path can be hardcoded.

Each `SKILL.md` opens with a "Helper paths" preamble telling the agent to
anchor on the file it was loaded from:

```bash
SKILL_DIR=$(dirname "$(realpath <skill-md>)")
bash "$SKILL_DIR/scripts/check-structure.sh"
cat "$SKILL_DIR/reference/mermaid-house-style.md"
```

Every `scripts/…` and `reference/…` reference is written as `"$SKILL_DIR/…"`.
The structural linter enforces this: any skill shipping helper files must
contain a `SKILL_DIR` anchor instruction, or `task lint` fails.

When `/docs-update` hits a `MISSING_ADR_INDEX` finding, it activates the `adr`
skill as well and binds `$ADR_DIR` from that skill's loaded location the same
way.

## Six commands, two skills

The commands are not one-per-skill. `/docs-init`, `/docs-audit`,
`/docs-update`, and `/diagram-test` all front `docs-organization`; `/adr-new`
and `/adr-review` front `adr`; `/docs-update` reaches both.

This is why the shared structural linter binds commands to skills **by
reference** rather than by filename. A command is valid if its filename matches
a skill directory or its body names one; an explicit skill is valid if any
command names it. The template's original linter required a one-to-one
filename match and rejected this module outright.

## The `/docs-audit` lanes

`/docs-audit` splits into deterministic script-owned lanes and model-owned
judgement. The command file marks the split with an `<EXECUTION-CONTRACT>`
block, and the contract is strict: the agent must run the named script and use
its JSON verbatim rather than eyeballing the file, even when reading directly
would be faster.

| Lane | Script | Finds |
| --- | --- | --- |
| 1 structural | `check-structure.sh` | missing or empty README, ungitignored `docs/superpowers/`, superpowers drafts tracked in git, an ADR directory with no `index.md` |
| 2 staleness | `check-staleness.sh` | docs older than the code they describe |
| 3 readability | `check-prose.mjs` | wall-of-text, dense bullets, unscannable procedures |
| 4 reference integrity | `check-refs.mjs` | broken links and file references |
| diagrams | `lint-mermaid.mjs` | syntax, init header, palette classes, contrast |

Convention 2 in `AGENTS.md` — developer documentation under `docs/dev/` — is
model-owned, not script-owned. Lane 1 does not check for it.

Splitting it this way is what makes the audit reproducible. The `eval/`
harness measures each lane's recall and false-positive rate against fixtures
with known ground truth; `eval/REPORT.md` records the results that justified
wiring each lane in.

## The palette system

Four palettes ship in `reference/palettes/`: Solar (default), Federation,
Citrus, and Parchment. Each covers every mermaid diagram type, so switching
palettes never leaves a diagram type unstyled.

Contrast is verified, not assumed. `contrast.mjs` computes WCAG ratios and
`validate-palette.mjs` asserts every palette meets text-on-fill ≥ 4.5:1 and
fill-on-background ≥ 3.0:1 against both light and dark reference backgrounds.
`lint-mermaid.mjs` enforces that every diagram carries the house-style
`%%{init}%%` header and uses palette classes (`sysA`…`sysF`, `edgeLabel`)
rather than inline colours.

`apply-palette.mjs` and `swap-palette.sh` rewrite an existing diagram to a
different palette. ER diagrams need a CSS override that mermaid's init block
cannot express, which is why `er-overrides.css` exists and why `task render`
passes it to `mmdc`.

Palette class names are load-bearing. Every diagram in every project using this
module references them by name, so renaming one is a breaking change.

## The install oracle

`task test:install` runs `.taskfiles/scripts/verify-lola-module.sh`, which:

- redirects `HOME` and `LOLA_HOME` into a fresh `mktemp -d`, so a user-scope
  install never touches your real `~/.claude`;
- installs from a copy of `module/` inside that sandbox, so a project-scope
  install — which writes into the current directory — lands in the sandbox
  rather than this checkout;
- **discovers** what to assert from `module/skills/*/` and
  `module/commands/*.md`, then looks for each under the scope root;
- asserts the `lola:module:docs-discipline` managed-section marker was
  injected into some context file;
- removes the sandbox via an `EXIT` trap, and dumps the tree on failure.

The discovery matters. lola moves install destinations between releases —
opencode's user-scope path moved from `~/.opencode/` to
`~/.config/opencode/` — and the CI workflow this replaced had a hardcoded
assertion that silently went stale. Skill directories are also named after the
skill, not the module, so asserting `skills/docs-discipline/` would never have
matched anything here.

## Why there is no `task install`

lola owns installation. It already has scope selection, assistant targeting,
and force prompts, and wrapping those in Task means shadowing a flag surface
that drifts the moment lola adds a flag. The README documents the `lola`
commands directly.

There is nothing left to wrap. Install is two `lola` commands with no
prerequisites — see the next section.

## Vendored dependencies

The skill shells out to two npm packages: `@aj-archipelago/merval` for mermaid
validation, and `markdown-it` for the `/docs-audit` prose and reference lanes.
Neither has ever reached an installed skill, because lola strips any directory
named `node_modules` from the copy it ships.

The name is the entire constraint. `ALWAYS_IGNORE` matches that one directory
name, not dependencies in general, so a `vendor/` directory ships verbatim at
any depth. Both packages are MIT and bundle cleanly, so they ship pre-built:

```text
scripts/vendor/merval.mjs        90K   @aj-archipelago/merval, no deps
scripts/vendor/markdown-it.mjs  240K   markdown-it + 6 transitive deps
scripts/vendor/LICENSES.md             MIT texts for all eight packages
```

`package.json` keeps both as `devDependencies` — they are build inputs, not
runtime imports — alongside a pinned `esbuild`. `task vendor` installs that
toolchain and regenerates all three files. CI reruns it and fails on a
non-empty `git diff vendor/`, so a committed bundle can never drift from the
version `package.json` pins. A Dependabot bump therefore arrives red until the
bundles are rebuilt, which is the intended signal.

`LICENSES.md` is assembled by `build-vendor.sh` from the installed packages'
own metadata and licence files, because esbuild only preserves `/*! */` legal
comments and neither package uses them. The list of packages to walk is
hardcoded in that script, so a new transitive dependency has to be added there
by hand.

Two consequences worth knowing. `MERVAL_NOT_INSTALLED` no longer exists — the
gap it reported cannot occur. And the install oracle asserts that every file
under a source skill directory arrives in the installed copy, which is what
would catch lola widening `ALWAYS_IGNORE` to swallow `vendor/`.

The alternative was a `module/lola.yaml` `post-install` hook running `npm
install` at the destination. It is blocked anyway: in lola v0.7.0 the hook
runner passes an empty `cwd` at user scope, so the hook dies with
`FileNotFoundError` and lola misreports it as "script is not executable".
Hooks work at project scope. Even fixed, a hook would need network and npm at
every install; vendoring needs neither.
