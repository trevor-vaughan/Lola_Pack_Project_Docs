# Deterministic where it's unambiguous, LLM where it's fuzzy

Design rationale for the split between what `check-prose.mjs` measures and what
the `/docs-audit` LLM lanes judge: which readability signals are mechanical
enough for a script to enumerate, which are not, and why each remaining check
sits on the side it does. The operative procedure — thresholds, prompts,
finding emission — lives in the script and in the `/docs-audit` command. This
file explains the reasoning behind it, and is loaded on demand rather than at
skill activation.

## Size is mechanical, so the script enumerates it

Size is a mechanical property: a paragraph's *word count*, a bullet's word count,
a file's or section's *line span*. Those are exact and reproducible, so
`check-prose.mjs` triggers on them alone — reading the markdown-it AST (fenced
code, tables, blockquotes, and nested lists distinguished by node type, not
regex) and enumerating byte-identically every run. An LLM asked to *enumerate*
readability problems under-reports on long files (recall fades toward the end)
and two runs disagree, so enumeration is the script's job.

## Sentence segmentation is not, so the LLM adjudicates it

What the script deliberately does **not** do is count sentences. Sentence
segmentation is a genuinely hard NLP problem — abbreviations (`e.g.`, `i.e.`,
`vs.`), decimals, initials, ellipses — that no regex gets right; a sentence
counter false-flags abbreviation-heavy technical prose. So the fuzzy judgments
are deferred to the LLM lane, which only ever adjudicates the candidates the
script surfaces: is the rhythm choppy, and is this a dense-prose *genre*
(academic paper, legal text, formal spec) where a `WALL_OF_TEXT` finding should
be suppressed. Deterministic backbone; LLM for the judgment residue.

## `DENSE_BULLET` covers the shape `WALL_OF_TEXT` excludes

`DENSE_BULLET` exists because the wall-of-text rule deliberately excludes lists,
so a 150-word flat bullet slips past it. A bullet already broken into
sub-bullets is the desired shape and is never flagged, however long overall.

## `NEEDS_STRUCTURE` measures absence of structure, not size

Every deterministic check above measures the size of a *single* block. The
complementary axis is a procedure spread across *many small* blocks — prose
interleaved with back-to-back command fences, no paragraph long enough to trip
`WALL_OF_TEXT`, no list to trip `DENSE_BULLET`, short enough to duck
`SPLIT_CANDIDATE` — yet with no list or sub-headings to give the eye a rest
point. That is absence-of-structure, not size, so it is judged by the grounded
`NEEDS_STRUCTURE` sub-check in Lane 5 rather than by `check-prose.mjs`. It fires
only on procedural runs (a command-by-command walkthrough, including a README
Install/Quickstart — this one is **not** landing-exempt), and never on
already-listed steps, a short one-or-two-command run, or non-procedural prose.
(Validated 25/25 on eval fixtures.)
