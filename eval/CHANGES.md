# Changes to the docs-organization skill

Motivation: make `/docs-audit` produce **consistently good** results. The
observed failure was the LLM readability lane under-reporting on long files;
investigation (see `eval/REPORT.md`) also surfaced a silent-empty-reply failure
mode in the content-drift lane. All changes are evidence-backed by the headless
eval harness under `eval/`.

## New file: `skill/scripts/check-prose.mjs` (+ `check-prose.test.mjs`)

A deterministic readability/size checker built on the markdown-it AST (fenced
code, tables, blockquotes, and nested lists are distinguished by node type — no
per-line regexes). Emits three info-level codes with `file:line`:

- `WALL_OF_TEXT` — a top-level paragraph over ~120 words / ~6 sentences.
- `DENSE_BULLET` — a **flat** list item (no sub-bullets) over ~90 words /
  ~5 sentences. A bullet already broken into sub-bullets is never flagged.
  This is the class the per-paragraph rule cannot catch (it excludes lists).
- `SPLIT_CANDIDATE` — a file over 600 lines, or an H2 section over 250 lines.

Output contract matches the other scripts: JSON `{status, findings}`, exit
0/1/2. Thresholds are named constants (`THRESHOLDS`) at the top of the file.
11 unit tests; the full suite is 72/72.

## Dependency: `markdown-it` (pinned `14.1.0`)

Added to `skill/scripts/package.json` alongside `@aj-archipelago/merval`, and
to the `test` script. Like merval, it needs a one-time `npm install` in the
installed `scripts/` dir.

## `/docs-audit` (`commands/docs-audit.md`)

- **Lane 3 is now deterministic readability** — runs `check-prose.mjs` instead
  of dispatching an LLM to hunt for wall-of-text. The LLM's only readability
  role is a genre-suppression judgment on files the script already flags.
- **Lane 4 (content + diagram drift) gains a never-silence guardrail** — an
  empty/errored subagent reply is retried up to twice, then recorded as a
  `LANE_FAILED` **Warning**. An unaudited file is "unknown", never "clean".
- Chunking content-drift is documented as optional insurance for very large
  files only — the eval showed whole-file recall is reliable to ~400 lines.
- Punch-list schema and example output extended with `DENSE_BULLET`,
  `SPLIT_CANDIDATE`, `LANE_FAILED`. Stop conditions cover `check-prose` errors.

## `/docs-update` (`commands/docs-update.md`)

- `DENSE_BULLET` fix: decompose a flat bullet into a lead-in plus nested
  sub-bullets, preserving every technical token.
- `SPLIT_CANDIDATE` fix: extract an audience-specific how-to under `docs/` with
  a pointer stub (explicit consent; default to not splitting maintainer docs).
- `LANE_FAILED` is explicitly not "fixable" — re-audit or inspect manually.

## `skill/SKILL.md`

- `check-prose.mjs` added to the tools list; deps note updated.
- New sections: "Readability is deterministic, not LLM-judged" and "Never read
  an empty LLM lane as clean".

## Not changed / deliberately rejected

- **Chunking content-drift by default** — not justified by the data.
- **A bigger model for readability** — wrong tool; a parser is exhaustive and free.

## Install (deliverable is source; regenerate `node_modules`)

```
cp -r skill/*      <installed-skill-dir>/        # SKILL.md, reference/, scripts/
cp    commands/*   <host-commands-dir>/          # docs-audit.md, docs-update.md, docs-init.md
cd <installed-skill-dir>/scripts && npm install  # markdown-it + merval
npm test                                         # expect 80 passing
```

---

## Round 2 additions (same session)

**Readability: dropped sentence counting.** `check-prose.mjs` now triggers on
word count and line span only. Sentence segmentation false-flagged
abbreviation-heavy prose (`e.g.`, `i.e.`, `§10.9`) — a hard NLP problem, so the
fuzzy sentence-rhythm/genre judgment is deferred to the LLM lane. Thresholds are
word-based (`paragraphWords` 120, `bulletWords` 90) plus size (`fileLines` 600,
`sectionLines` 250). Also fixed an O(n²) token scan.

**New file: `check-refs.mjs` (+ test).** Reference integrity:
- `REF_BROKEN` / `REF_NOT_IN_GIT` — a markdown link that doesn't resolve to a
  git-tracked file.
- `UNLINKED_REF` — a `§` section citation with no link (a deterministic tell for
  an unfollowable reference; fix by linking, never by stripping the `§`).
Scoped to markdown links + git-tracked docs only. Inline-code source-path
resolution was tried and removed (1478→6 findings on polypkg once corrected);
it's not cleanly deterministic.

**New LLM lanes (validated in eval): grounding + cold-read.**
- A per-file grounding pass (purpose / audience / reader-goal) threaded into
  every LLM lane so each judges for the intended audience.
- A `COLD_READ` lane: read the doc as that audience, flag comprehension blockers
  (undefined term, missing step, dangling ref, contradiction, terminology
  drift, unstated prerequisite, unresolvable spec citation). High-precision in
  eval (0 spurious, 4/5 traps).

**Command/skill wiring.** `/docs-audit` now has 5 lanes (added Lane 4 references,
Lane 5 grounding+content+diagram+cold-read). `/docs-update` handles the new
codes (link/commit/mark-external for refs — never strip `§`; author-owned for
cold-read). SKILL.md documents all of it.

---

## Round 3 additions (scannability of procedures + self-drift fixes)

**New Lane 5 sub-check: `NEEDS_STRUCTURE`.** The deterministic readability lane
measures the size of a *single* block, so it is blind to a procedure spread
across *many small* blocks — prose interleaved with back-to-back command fences,
each block under every threshold, but with no list or sub-headings to rest on
(the "running through commands with no break" case). That is absence-of-structure,
not size, so it is an LLM sub-check, not a script change. Grounded, info-level,
and — unlike `MODE_MIXING`/`INCOMPLETE_FOR_TYPE` — **not** landing-exempt, because
a README Install/Quickstart is exactly where a command wall hurts a first-timer.
`/docs-update` fix: break the run into a numbered list and/or per-phase
sub-headings, every command preserved verbatim. Validated before wiring: **25/25,
perfectly consistent** across 5 fixtures (see `eval/REPORT.md` Round 8,
`eval/run_needsstructure.py`).

**Self-drift fixes (the skill's own docs failed its own audit).**
- Test count stated three ways (`72/72`, `78`, `78/78`) — pinned the install
  instruction to the real `npm test` result (**80 passing**).
- `docs-update.md` said "run /docs-audit's three lanes inline" — stale since the
  lane count grew to five; now "run /docs-audit's lanes inline".
- `docs-update.md` step numbering collided (`5a` then `5`) — renumbered to
  5 (encouragement) and 6 (semantic).
- `check-prose.mjs` header claimed the parser "counts words and sentences" — it
  stopped counting sentences in Round 2; comment corrected.

No script logic changed this round (the new check is LLM-only), so the unit suite
is unchanged at **80/80**.

---

## Round 4 additions (hero-demo encouragement)

**New Lane 5 sub-check: `MISSING_DEMO`.** Trending READMEs lead with an animated
demo (asciinema / GIF / VHS); a landing page for a user-facing tool that shows
nothing running is a real gap. Built as the demo sibling of `MISSING_DIAGRAM` —
same strict-bar, info-level, opt-in encouragement contract, scoped to a
README/landing page for a **runnable tool** (CLI / TUI / app), never a library, a
spec, or a maintainer doc, and never when a demo/screenshot already exists.

Because an LLM cannot record a screencast, the `/docs-update` fix is an
**HTML-comment spec** at the hero slot (command sequence to record, what the
viewer should see, suggested format) that **points at** asciinema / VHS — it does
**not** scaffold a `.tape` or fabricate an artifact (deliberately kept simple;
mermaid scaffolding is already enough finicky-artifact surface).

Validated before wiring: **25/25, perfectly consistent** across 5 fixtures (a CLI
and a TUI flag; a library, a maintainer doc, and a README that already has a GIF
stay silent). The already-has-a-demo case holding 5/5 is why **no deterministic
pre-filter script was added** — the LLM detects an existing demo on its own. See
`eval/REPORT.md` Round 9, `eval/run_missingdemo.py`. Suite unchanged at **80/80**
(LLM-only check).
