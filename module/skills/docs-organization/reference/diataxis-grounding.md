# Grounding, cold read, and completeness — why these lanes are shaped this way

Design rationale for the three LLM lanes in `/docs-audit` that judge a document
by what it is *for*: the Diátaxis grounding pass, the cold read, and the
completeness check. The operative procedure — prompts, retries, finding
emission — lives in the `/docs-audit` command. This file explains the reasoning
behind it, and is loaded on demand rather than at skill activation.

## Ground the review in Diátaxis

Every LLM lane runs better knowing what the document is *for*. A one-line
grounding pass classifies the file's [Diátaxis](https://diataxis.fr) mode —
`tutorial`, `how-to`, `reference`, `explanation`, or `landing` (a README/entry
page, legitimately multi-mode) — plus audience and reader-goal, and threads it
into the content-drift, missing-diagram, cold-read, and structure prompts. The mode makes
the other lanes' judgments principled rather than ad hoc: dense unbroken prose
is a convention in `reference`/`explanation` but a defect in `tutorial`/`how-to`;
"would a reader get stuck" is a tutorial/how-to question, while `reference` is
judged on completeness. Grounding also emits `MODE_MIXING` (info) when a
non-`landing` doc commits to one mode but embeds another that interrupts its job
(a how-to that detours into pages of concept). It is a **lens, not a law**: a
`landing` page is never flagged for mixing, and the finding is info-level — the
framework guides, it does not dictate. (Validated: 5/5 consistent on eval
fixtures, with the landing page exempted from `MODE_MIXING` rather than
flagged.)

## Then cold-read it

The **cold read** is the lane none of the narrow checks cover: read the doc as
the intended audience and flag where a real reader gets stuck — an undefined
term, a missing step, a dangling "see below", prose that contradicts its own
example, terminology that drifts, an unstated prerequisite, a spec citation the
reader can't resolve. Measured on the eval fixture it is high-precision (0
spurious findings, 4/5 planted traps caught), so its findings are treated as
real but kept info-level.

## Completeness, without a section checklist

A companion **completeness** check (`INCOMPLETE_FOR_TYPE`) uses
[The Good Docs Project](https://www.thegooddocsproject.dev) notion of what each
Diátaxis type needs — a troubleshooting doc pairs every symptom with a
resolution, a reference describes every listed entry, a how-to names the
prerequisites its steps assume. It is **not** a section-checklist: it fires only
for a reader who would be *blocked*, never for a missing named heading, and
never on a `landing` page. That guard is load-bearing — without it the check
nagged even a complete how-to (0/5); with it, 20/20 on the eval (full recall on
real gaps, zero nagging on complete or intentionally-minimal docs).
