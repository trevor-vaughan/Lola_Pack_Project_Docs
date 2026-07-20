# docs-audit reviewer — evaluation report

Goal: make the `/docs-audit` reviewer produce **consistently good** results.
Everything below was measured with the real `claude` CLI in headless mode
(`claude -p ... --output-format json`), scored against ground-truth fixtures —
no hand-correction. Re-run with `eval/run_drift.py` and `eval/run_diagram.py`.

## Method

- Fixtures live in `eval/fixtures/<case>/` with an `expected.json` ground truth.
- LLM lanes are invoked with the lane's **exact prompt fed inline** (in
  `eval/prompts/`), not by asking the CLI to "run the skill". Headless sessions
  tend to ignore sub-skill material and freelance at the top level; feeding the
  prompt directly removes that variable.
- Each LLM lane is run K=5 times per fixture. We report per-item recall, the
  run-to-run finding set (consistency), and false positives.
- Model: `claude-sonnet-5`.

## Finding 1 — readability was the real inconsistency; now deterministic

The originally-observed failure was the LLM readability lane under-reporting
wall-of-text on a long file. *Size* is a mechanical property (word count, line
span over AST-classified regions), so it does not belong to an LLM.

`scripts/check-prose.mjs` reads the markdown-it AST and counts exhaustively.

- Unit tests pass (80 across the whole suite).
- Output is **byte-identical across runs** (md5 stable over 3 runs).
- It triggers on **word count and line span only** — both unambiguous. An
  earlier cut also counted sentences; that was removed after it false-flagged
  abbreviation-heavy prose ("e.g.", "i.e.", "§10.9"): sentence segmentation is a
  hard NLP problem, so the fuzzy "is the rhythm choppy / is this a dense-prose
  genre" judgment is deferred to the LLM lane. Deterministic where it's
  unambiguous, LLM where it's fuzzy.

This lane is now 100% reproducible by construction. It also adds two codes the
old per-paragraph rule structurally could not catch:

- `DENSE_BULLET` — a flat list item (no sub-bullets) over threshold. The
  wall-of-text rule excludes lists, so a 150-word flat bullet slipped past it.
- `SPLIT_CANDIDATE` — an oversized file or H2 section (audience-split nudge).

## Finding 2 — content-drift whole-file is reliable; chunking was NOT justified

| Fixture | Lines | Planted drifts | Mode | K | Mean recall | Consistent | FP |
|---|---|---|---|---|---|---|---|
| content-drift-long | 252 | 4 | whole | 5 | 1.00 | yes | 0 |
| content-drift-xl | 400 | 7 | whole | 5 | 1.00 | yes | 0 |
| content-drift-huge | 376 | 9 | whole | 5 | **0.80** | **no** | 0 |

The huge-fixture dip looked like recall decay but was not: 4 of 5 runs found
**all 9** drifts; run 1 returned an **empty** reply that scored as zero. The
model finds everything when the call succeeds — even a drift on the last line of
a 400-line doc. Chunking-by-section (my initial hypothesis) is unnecessary
overhead at these sizes and is **not** added as a default.

## Finding 3 — the real LLM-lane risk is a transient empty reply read as "clean"

A blank/errored subagent reply silently becomes "no findings" — a spurious
all-clear. Adding **validate-and-retry** (retry until a parseable JSON object,
up to 3 attempts) closed the gap:

| Fixture | Mode | K | Mean recall | Consistent |
|---|---|---|---|---|
| content-drift-huge | whole + retry-on-empty | 5 | **1.00** | **yes** |

Per-run: all 5 runs found 9/9. The command procedure now retries empty/errored
subagents and records a `LANE_FAILED` **Warning** if a lane still yields
nothing — an unaudited file is "unknown", never "clean".

## Finding 4 — the missing-diagram lane is consistent with a strict prompt

| Fixture | Expected | K=5 result |
|---|---|---|
| diagram-branchy (state machine) | suggest | `[True,True,True,True,True]` |
| diagram-linear (4-step install) | don't | `[False,False,False,False,False]` |

## The five lanes after this work (see ../CHANGES.md)

| Lane | Kind | Codes |
|---|---|---|
| 1 Structural | deterministic | `MISSING_*`, `SUPERPOWERS_IN_GIT`, … |
| 2 Staleness | deterministic | `STALE_*` |
| 3 Readability/size | deterministic (`check-prose.mjs`) | `WALL_OF_TEXT`, `DENSE_BULLET`, `SPLIT_CANDIDATE` |
| 4 Reference integrity | deterministic (`check-refs.mjs`) | `REF_BROKEN`, `REF_NOT_IN_GIT`, `UNLINKED_REF` |
| 5 Grounding + content/diagram/cold-read | LLM, validated + retry-guarded | drift, `MISSING_DIAGRAM`, `COLD_READ`, `LANE_FAILED` |

The rule throughout: deterministic where the metric is unambiguous (word/line
counts, git-tracked link resolution); LLM where the judgment is fuzzy (drift,
diagram value, comprehension, genre) — always grounded, always retry-guarded.

## Reproduce

```
cd skill/scripts && npm install         # markdown-it + merval
npm test                                # 80 unit tests
cd ../../eval
python3 run_drift.py --fixture fixtures/content-drift-huge --mode whole --runs 5 --out results/repro.json
python3 run_diagram.py fixtures/diagram-branchy 5
python3 run_coldread.py fixtures/cold-read grounded 5
```

## Finding 5 — a grounded cold-read lane is high-precision (added)

None of the narrow lanes reads the doc *as a human user*. Added a cold-read lane
(read as the intended audience; flag comprehension blockers) preceded by a
one-line grounding pass (purpose/audience/goal) threaded into every LLM lane.

Fixture `fixtures/cold-read/` plants 5 traps (missing step, undefined jargon,
dangling cross-ref, prose-vs-example contradiction, terminology drift).

| Mode | K | Mean recall | Spurious/run | Robust traps (≥3/5) |
|---|---|---|---|---|
| ungrounded | 5 | 0.76 | **0.0** | 4/5 |
| grounded | 5 | 0.80 | **0.0** | 4/5 |

Zero spurious findings in either mode — the lane is high-precision. The one
consistently-missed trap is "widget never defined", which is genuinely
borderline jargon. Grounding barely moved recall here because the fixture
self-states its purpose; its real value is precision on *wrong-audience* docs
(suppressing maintainer-doc false positives), and it sharpens the other lanes.
Run: `python3 run_coldread.py fixtures/cold-read grounded 5`.

## Finding 6 — reference integrity is mostly deterministic (added)

"A reference should be followable." `scripts/check-refs.mjs` resolves markdown
links against the git-tracked set (`REF_BROKEN`, `REF_NOT_IN_GIT`) and flags
`§` citations with no link (`UNLINKED_REF`).

Design lesson (the hard way): the first cut also resolved *inline-code* source
paths and walked gitignored dirs — 1478 findings on polypkg, almost all false
positives (`internal/x.go` resolved doc-relative; `<dir>/x.yaml` placeholders;
1400 hits inside gitignored `docs/superpowers/`). Scoping to **markdown links
only** + **git-tracked docs only** dropped it to **6 real findings** — exactly
the `§` spec-citations pointing at uncommitted specs. Inline-path resolution is
not cleanly deterministic, so it was removed (stale source mentions are the
content-drift lane's job). 4 unit tests; whole suite grew to 80/80.

## Round 3 — loop over the real lolables org (4 repos)

Swept all four `github.com/lolables` repos (`lola-mod-review-council`, `market`,
`skill-commit`, `lola-mod-lolafy`, ~36 docs) with the deterministic lanes, then
inspected every finding against the test "would acting on it make the doc
*better*?" No crashes. Three issues found and fixed:

1. **`check-refs`: directory links false-flagged.** A link to a tracked
   directory (`[agents](module/agents/)`) was reported `REF_NOT_IN_GIT` because
   git lists files, not dirs. Fixed by resolving against the set of tracked
   directory *prefixes*; a dir containing tracked files is followable. (2 tests.)

2. **`check-structure`: `MISSING_GITIGNORE_SUPERPOWERS` fired as a blocker on
   repos with no `docs/` tree** — 3 of 4 lolables repos. Adding the preventive
   gitignore entry to a repo that has no docs and doesn't use the workflow
   improves nothing. Gated the check on a `docs/` directory existing; it still
   fires the instant superpowers writes `docs/superpowers/`. (2 tests.)

3. **`check-prose`: `SPLIT_CANDIDATE` advice was README-specific** ("extract a
   how-to under docs/"). On a `SKILL.md` the right move is to move detail into a
   `reference/` file, not `docs/`. Made the advice generic so the suggestion
   fits the document type.

Remaining findings across the org are legitimate, value-adding info nudges: one
`SPLIT_CANDIDATE` (a 281-line SKILL.md section) and one `DENSE_BULLET` (a verify
step cramming three distinct actions — sub-bullets would genuinely help).

Guiding principle this round: a finding only earns its place if acting on it
makes the doc reliably better. False-positive blockers and doc-type-mismatched
advice fail that bar and were fixed.

## Round 3b — full headless audit on a real repo (the payoff)

Ran the complete `/docs-audit` (all five lanes, real subagents) headless against
`skill-commit`. Result: `0 blockers, 0 warnings, 3 info`. The four deterministic
lanes correctly found **nothing** (no false positives after the Round-3 fixes),
and the cold-read lane surfaced three verified-real, high-value issues that no
mechanical check could:

1. `SKILL.md:64` — the commit-subject limit is stated three ways: "max 50 chars"
   (L43), "72" (L46), and "hook rejects over 62 **bytes**" (L64) — a unit shift
   (chars→bytes) an author can't reconcile. Not drift (README and SKILL.md
   agree); *internal* under-specification.
2. `README:9` — install uses `lola mod add` / `lola install` but never says
   `lola` is a prerequisite (verified: 0 mentions); a first-timer hits
   `command not found`.
3. `README` — the skill is installed as `skill-commit` but invoked as `/commit`
   (name mismatch), and the README never states the trigger.

All three were spot-checked against the source and confirmed real. This is the
lane the whole exercise was for: deterministic lanes stay silent when there is
nothing mechanical to say, and the LLM lane earns its place on exactly the
judgment calls — each finding, if acted on, makes the doc reliably better.

## Round 4 — grounding on Diátaxis (validated before wiring)

The grounding pass now classifies each doc's Diátaxis mode (`tutorial`,
`how-to`, `reference`, `explanation`, or `landing`) and emits `MODE_MIXING`
(info) when a non-landing doc commits to one mode but embeds another. The mode
also makes readability genre-judgment principled: dense prose is a convention in
`reference`/`explanation`, a defect in `tutorial`/`how-to`.

Validated first (fixtures in `fixtures/diataxis-*`, `run_diataxis.py`, K=5):

| Fixture | Expected | primary_mode (×5) | mode_mixing (×5) | correct |
|---|---|---|---|---|
| diataxis-mixed (how-to + concept detour + ref table) | mixing | how-to | True | 5/5 |
| diataxis-clean (focused how-to) | clean | how-to | False | 5/5 |
| diataxis-landing (README blend) | clean (exempt) | landing | False | 5/5 |

15/15, perfectly consistent, and — the key result — the README/landing page is
correctly **exempted**, so the framework is a lens, not a dogmatic nag. That
exemption is what keeps it reliably good.

**On The Good Docs Project templates** (a natural complement — Diátaxis is the
taxonomy, Good Docs is the per-type template of expected sections): deliberately
NOT wired as a rigid `MISSING_SECTION` linter. Two opinionated frameworks
stacked into hard findings would nag every doc for a missing template section.
The intended use is as a *reference the cold-read consults* for the classified
type ("a troubleshooting doc with symptoms but no resolutions") — info-level,
validated separately, never a checklist. Left as a documented next step, not
built on assumption.

## Round 5 — Good Docs completeness (measured NO, then YES with a guard)

Tested a Good-Docs-Project-informed completeness check (does a doc contain what
its Diátaxis type needs?) — the check I had warned could become a
section-checklist martinet. Fixtures in `fixtures/gooddocs-*`, `run_gooddocs.py`.

First cut (recall vs anti-nag), K=5:

| Fixture | Kind | Expect | Result | |
|---|---|---|---|---|
| troubleshoot-gap (symptoms, no fixes) | recall | flag | 3/5 | inconsistent |
| reference-gap (blank table cells) | recall | flag | 5/5 | reliable |
| howto-complete (prereqs+steps+end) | anti-nag | silent | **0/5** | **nagged every run** |
| minimal-ok (tiny but complete) | anti-nag | silent | 5/5 | good |

The complete how-to was nagged every batch (e.g. "step 2 gives no exact
command") — the martinet, confirmed. So I did NOT wire the first cut.

Adding one guard — *flag a reader who is BLOCKED, never one who merely wants
more detail; never a missing named section* — flipped it:

| Fixture | Result |
|---|---|
| troubleshoot-gap | 5/5 |
| reference-gap | 5/5 |
| howto-complete | 5/5 silent |
| minimal-ok | 5/5 silent |

**20/20.** Full recall on real gaps, zero nagging on complete/minimal docs. That
guard made it reliably good, so it is wired as `INCOMPLETE_FOR_TYPE` (info,
landing-exempt). Both opinionated frameworks (Diátaxis, Good Docs) turned out to
need the same thing: an explicit *what-to-ignore* escape hatch. Encoding what a
framework should NOT flag is what separates a lens from a nag.

## Round 6 — full audits on real repos (whole Lane 5, verified)

Ran the complete `/docs-audit` headless on real lolables repos and spot-checked
every high-value finding against source (a confident hallucination is worse than
a miss).

**market (1 doc).** Grounding classified the 2-line README as `landing`, so
`MODE_MIXING` and `INCOMPLETE_FOR_TYPE` **auto-exempted** — the five sub-checks
self-suppressed by mode instead of all firing. One `COLD_READ` (README is a stub:
undefined terms, no install/quickstart, doesn't list the modules `lola.yml`
ships). Verified real.

**lolafy (5 in-scope docs).** `0 blockers, 1 warning, 9 info`. All findings
distinct and, on spot-check, real:
- README:90 — "Host checks (need only `lola`)" lists `task lint:content`, which
  needs `uvx` — a first-timer hits a failure. Verified.
- lola-target.md:136 — reference lists 5 assistant keys, but
  `verify-lola-module.sh:49` `die`s on any `--assistant` ≠ `claude-code`. Verified.
- SKILL.md:82 — a grammatically broken, invented instruction against the skill's
  own guardrail. Verified.

Crucially, the **anti-nag guards fired on real docs**: an `INCOMPLETE_FOR_TYPE`
and a `MODE_MIXING` were *suppressed with stated reasons* (not silently dropped),
and the `MODE_MIXING` that did fire was self-hedged ("mild — reference-with-usage
is common"). No flood (~2 findings/doc), no silent duplication between sub-checks.

**One honest blemish:** one finding's *framing* over-reached — it labeled
SKILL.md:82 a "contradiction" of a rule that was actually about a different
subject. The underlying finding is real (broken, dubious instruction), so acting
on it still improves the doc, but the LLM occasionally over-frames at the margin.
Reliably good, not perfect — which was the bar.

(The 25-doc `review-council` scale run is the last check; results appended when
it lands.)

### review-council (25 docs) — the scale test

`0 blockers, 5 warnings, 13 info`. Verified pass:
- **Scoped itself**: ran the LLM sub-checks only on the 7 real doc files
  (README, 2 SKILL.md, 4 phases/*.md); swept the ~18 persona/pack files with the
  deterministic lanes only, correctly reasoning they are "LLM prompts /
  machine-checked rules, not Diátaxis docs." No blind fan-out over 25 files.
- **Verification caught a false positive**: one sub-check claimed an eval-table
  "disagreement"; the verify step found the tables reconcile (per-host vs
  averaged: 0.73 + 1.00 → 0.87) and **dropped it before the punch list**.
- **Findings verified & precisely cited**: e.g. `verify.md:46` documents
  `duplicates_consolidated` as an array of objects; `rc-verify-evidence.sh:416`
  emits it as an integer count (`$(( ... ))`, `:427`). Independently confirmed —
  the audit did not fabricate line numbers.
- Distinct codes (schema `CONTENT_DRIFT`, `COLD_READ`, `INCOMPLETE_FOR_TYPE`,
  deterministic `SPLIT_CANDIDATE`), ~2.5 findings/doc, severity hedged. No
  over-firing, no sub-check collision at scale.

**Overall:** across four real repos (deterministic sweep + three full audits),
the deterministic lanes had zero false positives after the Round-3 fixes, and
Lane 5 produced distinct, verified-real, appropriately-hedged findings — with its
anti-nag guards and its verify-and-drop guardrail both firing on real docs. The
reviewer is reliably good, not perfect (one over-framed label at the margin).

## Round 7 — is the over-framed finding fixable, or noise?

The lolafy audit over-framed one finding (labeled a "contradiction" between
statements about adjacent-but-different subjects). Investigated whether it is a
reproducible defect or stochastic noise.

- Isolated contradiction trap (adjacent-but-different subjects), base vs guarded
  prompt, K=5 each: **0/5 over-framed either way** — the finder labels it
  correctly (unsupported-instruction) without any guard.
- The actual content-drift prompt with code present, K=6: **empty 6/6** — it
  never strays into the cross-doc contradiction.

Two experiments, ~11 targeted runs, **zero reproductions**. The error appeared
only once, in the full 5-lane aggregated run — i.e. emergent at aggregation
(likely a cold-read/consistency observation relabeled as `CONTENT_DRIFT`), not a
reproducible weakness of any lane. A finder-prompt guard is therefore not
validatable and the data says it wouldn't help.

The one correct-anyway mitigation (not a claimed cure): a lane-boundary
clarification in the schema — `CONTENT_DRIFT` is doc-vs-code only; a doc-vs-doc
inconsistency is a `COLD_READ` finding, and "contradiction" requires a shared
subject. Fixtures: `fixtures/contradiction-trap`, `run_contradiction.py`,
`run_realdrift.py`.

## Round 8 — scannability of procedures (`NEEDS_STRUCTURE`, validated before wiring)

The deterministic readability lane measures the size of a *single* block
(`WALL_OF_TEXT` a paragraph, `DENSE_BULLET` a bullet, `SPLIT_CANDIDATE` a
file/section). It has a structural blind spot: a procedure spread across *many
small* blocks — prose interleaved with back-to-back command fences, no paragraph
long enough to trip `WALL_OF_TEXT`, no list to trip `DENSE_BULLET`, short enough
to duck `SPLIT_CANDIDATE` — yet with no list or sub-headings to give the eye a
rest point. This is the "running through commands with no break" case. It is
absence-of-structure, not size, so it is judged by an LLM sub-check, not a script.

Validated first (fixtures in `fixtures/needs-structure-*`, `run_needsstructure.py`,
K=5), scored like the Good Docs check (recall on docs that should flag, anti-nag
on docs that should stay silent):

| Fixture | Kind | Expect | Result |
|---|---|---|---|
| needs-structure-dense (how-to, 6+ commands as unbroken prose+code) | recall | flag | 5/5 |
| needs-structure-readme (README Install, 6 commands as prose) | recall | flag | 5/5 |
| needs-structure-clean (same procedure, already a numbered list) | anti-nag | silent | 5/5 |
| needs-structure-reference (dense but non-procedural explanation) | anti-nag | silent | 5/5 |
| needs-structure-short (a 2-command run) | anti-nag | silent | 5/5 |

**25/25, perfectly consistent.** Full recall on procedures that need breaking up,
zero nagging on already-listed steps, non-procedural prose, or runs too short to
scaffold. The key design decision (validated by the `-readme` fixture): unlike
`MODE_MIXING`/`INCOMPLETE_FOR_TYPE`, this check is **not** landing-exempt — a
README Install/Quickstart is exactly where a command wall hurts a first-timer, so
a `landing` page is in scope here. Wired as `NEEDS_STRUCTURE` (info) in Lane 5.
Run: `python3 run_needsstructure.py`.

## Round 9 — hero-demo encouragement (`MISSING_DEMO`, validated before wiring)

Trending READMEs lead with an animated demo (asciinema / GIF / VHS). A landing
page for a user-facing tool that shows nothing running is a real gap — but an LLM
cannot record a screencast, so the "fix" can only ever be a *spec of what to
record*, dropped as an HTML comment at the hero slot. Built as the demo sibling
of `MISSING_DIAGRAM`: same strict-bar, info-level, opt-in encouragement contract.

The make-or-break here is anti-nag (every README without a GIF is a nag magnet)
and one deterministic-looking question — "does a demo already exist?" — that we
chose to leave to the LLM and *test* rather than assume. Fixtures in
`fixtures/missing-demo-*`, `run_missingdemo.py`, K=5:

| Fixture | Kind | Expect | Result |
|---|---|---|---|
| missing-demo-cli (CLI with a live progress bar, no demo) | recall | flag | 5/5 |
| missing-demo-app (Kubernetes TUI, no screencast) | recall | flag | 5/5 |
| missing-demo-has-gif (CLI whose README already leads with a `.gif`) | anti-nag | silent | 5/5 |
| missing-demo-library (a Go retry library, code-snippet is the demo) | anti-nag | silent | 5/5 |
| missing-demo-reference (maintainer architecture doc) | anti-nag | silent | 5/5 |

**25/25, perfectly consistent.** The `-has-gif` result is the load-bearing one:
the model reliably detects an existing demo from the raw markdown and stays
silent, so **no deterministic pre-filter script was needed** — the data decided
that, rather than us building a `check-demo.mjs` on assumption. Wired as
`MISSING_DEMO` (info, encouragement bucket, README/landing only). The
`/docs-update` fix is an HTML-comment spec pointing at asciinema/VHS; it never
scaffolds a `.tape` or fabricates a recording. Run: `python3 run_missingdemo.py`.
