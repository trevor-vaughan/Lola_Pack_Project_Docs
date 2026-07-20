---
description: Apply fixes for drift findings produced by /docs-audit, with per-fix confirmation
argument-hint: "[path-to-saved-audit-output]"
---

# /docs-update

Take a punch list from /docs-audit and apply fixes interactively. Mechanical
fixes (gitignore entries, missing template files) get one batch confirmation;
semantic fixes (rewriting paragraphs) get per-fix confirmation.

## User-provided arguments

> $ARGUMENTS

## Instructions

### Activate the docs-organization skill

Invoke the `docs-organization` skill via your host's Skill tool. The skill's
`SKILL.md` defines `$SKILL_DIR` as the directory the host loaded it from
(`SKILL_DIR=$(dirname "$(realpath <loaded-skill-md>)")`). Reuse `$SKILL_DIR`
for every `scripts/...` and `reference/...` reference below — do not
hardcode `.claude/skills/...` or search candidate paths.

If the punch list contains a `MISSING_ADR_INDEX` finding, additionally
activate the companion `adr` skill and bind `$ADR_DIR` from its loaded
`SKILL.md` location the same way. If no `MISSING_ADR_INDEX` finding is
present, skip the `adr` activation.

### Steps

1. Read `$SKILL_DIR/SKILL.md` for the invariants and principles this skill enforces. The procedure below is the source of truth for what to do.
2. **Obtain the punch list:**
   - If `$ARGUMENTS` is a path to a saved audit output, parse it.
   - Otherwise, run /docs-audit's lanes inline to produce a fresh punch list.
3. **Sort findings into three buckets:**
   - **Mechanical:** `MISSING_GITIGNORE_SUPERPOWERS`, `SUPERPOWERS_IN_GIT`,
     `MISSING_ADR_INDEX`, `MISSING_HOUSE_STYLE_HEADER`, missing template
     files. Each has a deterministic fix.
   - **Encouragement (info-level):** `MISSING_DIAGRAM` (a section that would
     benefit from a diagram) and `MISSING_DEMO` (a README hero slot that would
     benefit from a demo recording). Both are optional nudges presented in one
     ranked menu; skip by default if the user declines and never auto-apply.
   - **Semantic:** content drift, diagram drift, `STALE_README`, `STALE_DOC`,
     `WALL_OF_TEXT`, `DENSE_BULLET`, `SPLIT_CANDIDATE`, `REF_BROKEN`,
     `REF_NOT_IN_GIT`, `UNLINKED_REF`, `COLD_READ`, `MODE_MIXING`,
     `INCOMPLETE_FOR_TYPE`, `NEEDS_STRUCTURE` findings, and anything else
     needing judgment.
     (`LANE_FAILED` is not fixable here — see stop conditions.)
4. **Apply mechanical fixes:**
   - Show the user the full list of mechanical fixes. Ask once: "Apply all
     mechanical fixes?" If yes, apply them in sequence.
   - Specific fixes:
     - `MISSING_GITIGNORE_SUPERPOWERS`: append `docs/superpowers/` to
       `.gitignore`.
     - `SUPERPOWERS_IN_GIT`: `git rm --cached <each tracked file>`.
     - `MISSING_ADR_INDEX`: run `bash $ADR_DIR/scripts/adr-index.sh
       <adr-dir>`.
     - `MISSING_HOUSE_STYLE_HEADER`: read
       `$SKILL_DIR/reference/mermaid-house-style.md`,
       prepend the required init header to each affected diagram.
     - Missing template files: read the relevant template from `reference/`
       and write it.
   - **Lint before commit:** if any mechanical fix modified a `.mmd` file
     or a `.md` file containing a fenced ```mermaid block, run
     `node $SKILL_DIR/scripts/lint-mermaid.mjs <file>`
     and confirm `status: ok` before staging.
   - Commit as a batch: `docs: apply structural fixes from /docs-audit`.

5. **Apply encouragement fixes via batch selection:**

   The encouragement bucket is info-level by design. Findings are
   *nudges*: independent, optional, and the author's main question is
   "which of these is worth my time?" — not "should I do this specific
   one?". Replace per-finding gates with one ranked menu.

   - **Rank candidates by likely value before presenting.** Diagram types
     differ in how dramatically they beat prose:
     - `stateDiagram-v2` / `erDiagram` — the concept *is* a graph (state
       machine, entity relationships). Prose has to enumerate every
       edge. **Highest value.**
     - `flowchart` with decision nodes — branching logic that flattens
       awkwardly into nested bullets. **High value.**
     - `flowchart` for component layout or pipeline stages — useful but
       bullet lists carry similar content. **Medium value.**
     - `sequenceDiagram` — valuable only when actor identity *and*
       ordering both matter. Otherwise a numbered list works.
       **Medium value.**
   - Present all candidates in a single multi-select prompt ordered by
     rank, each row showing: file, section heading, suggested diagram
     type (or, for a `MISSING_DEMO`, "hero demo"), one-sentence
     justification. Any `MISSING_DEMO` finding joins the same menu.
     **Selecting none is a valid outcome** — never auto-apply, and never
     warn about declining.
   - For each selected **`MISSING_DIAGRAM`** finding, in order:
     1. Read `$SKILL_DIR/reference/mermaid-house-style.md`
        — both the init header *and* the **Syntax constraints** section.
        The syntax constraints are non-obvious and load-bearing: violate
        them and the first lint will fail.
     2. Read the section's surrounding prose to ground the scaffold.
        Node names come from concepts the section already names; edges
        reflect relationships it already describes. **Do not emit
        generic `A --> B` placeholders** — a grounded skeleton is much
        faster for the author to refine than an empty one.
     3. Insert the fenced ```mermaid block immediately after the section
        heading, before any prose in the section body.
     4. **Lint before commit:** run
        `node $SKILL_DIR/scripts/lint-mermaid.mjs <file>`
        and confirm `status: ok`. If a `SYNTAX_ERROR` appears, consult
        the **Syntax constraints** section in the house-style reference
        and fix before committing.
     5. Commit individually with the file basename in the subject so
        commits across multiple files don't collide:
        `docs(<basename>): scaffold <diagram-type> under "<section>"`.
        Examples:
        - `docs(adr-skill): scaffold stateDiagram-v2 under "Status workflow"`
        - `docs(docs-audit): scaffold flowchart under "Instructions"`
   - For each selected **`MISSING_DEMO`** finding (the fix differs — an LLM
     cannot record a demo, so it drops a *spec*, not an artifact):
     1. Insert an **HTML comment** at the README hero slot (immediately after
        the title/tagline, before the first section). It is invisible in the
        rendered README, so it never ships a visible TODO. Fill it from the
        finding's spec — the command sequence to record, what the viewer should
        see, and the suggested format — and point the author at a tool rather
        than trying to build the recording:

        ```
        <!-- DEMO: add a hero demo showing <tool> in action.
             Record: <the happy-path command sequence from the finding>
             Viewer sees: <what success looks like on screen>
             Format: asciinema + svg-term-cli, or VHS (https://github.com/charmbracelet/vhs),
                     for a terminal; a short screen capture for a GUI.
             Place the rendered .gif/.svg/.cast here and link it above. -->
        ```

        Do **not** scaffold a VHS `.tape` or fabricate a recording — the spec is
        the deliverable; the human records it.
     2. No lint step applies (no mermaid touched).
     3. Commit: `docs(<basename>): note hero demo to record in README`.

6. **Apply semantic fixes one at a time:**
   - For each semantic finding, show the user:
     - The file and location.
     - What the doc currently says (exact excerpt).
     - What the code actually does (citation). For `WALL_OF_TEXT` there is
       no code citation; instead show the proposed paragraph breaks.
     - Proposed rewrite. For `WALL_OF_TEXT`, pick the lighter of two structure
       changes. Both keep every fact and claim in the paragraph:
       - **Whitespace reflow** — insert blank lines at topic seams to yield two
         to four coherent paragraphs, changing nothing but whitespace. Use when
         the paragraph is one continuous argument that just runs long.
       - **Sub-bullet restructure** — when the paragraph *enumerates* several
         distinct mechanisms or rules, lift each into its own bullet. You may
         trim connective words ("and", "while", "so") so each bullet reads
         grammatically, but never drop or reword a fact. Use when the reader
         would otherwise hold several ideas at once (the "four ideas" test in
         `module/AGENTS.md`).
       Never one sentence per line. Skip the finding entirely for
       academic/formulaic genres where dense prose is the convention.
     - For `DENSE_BULLET`: the fix is a **sub-bullet decomposition**. Keep the
       bullet's existing lead-in (often a bold phrase) as a short lead line,
       then lift each mechanism/clause into its own 2-space-indented
       sub-bullet, one idea per line. Preserve every technical token verbatim
       (code spans, symbols, numbers); you may trim connective words. A bullet
       that already nests sub-bullets is the target shape — never re-flatten it.
     - For `NEEDS_STRUCTURE`: the fix is a **procedural restructure** — break the
       flagged run into rest points the eye can land on. Convert the sequence of
       commands into a numbered list (one step per item), and/or add a short
       sub-heading per phase when the procedure has distinct stages. Preserve
       every command, flag, and path **verbatim** (same rule as `DENSE_BULLET`);
       you may lift connective prose into a one-line description per step, but
       never drop or reword a command. A procedure already in a list is the target
       shape — never re-flatten it. Show the proposed step breakdown before
       applying. (Fires on a README Install/Quickstart too — the README staying
       self-sufficient is unaffected; this only reshapes existing content.)
     - For `SPLIT_CANDIDATE`: the fix is **structural, and needs explicit
       consent** — it moves content between files. Propose extracting the
       oversized file (or the named H2 section) into an audience-specific
       how-to under `docs/` (e.g. `docs/publishing.md`), moving the content
       verbatim and leaving a short pointer stub in the original. Confirm the
       README (or parent) stays self-sufficient for onboarding after the move.
       Default to *not* splitting a maintainer design doc unless the user asks.
     - For `REF_BROKEN` / `REF_NOT_IN_GIT` / `UNLINKED_REF`: a reference should
       be *followable*, but how to make it so is the author's call — present
       options, do not auto-pick. Offer: (a) repoint/add a link to the correct
       in-repo target; (b) commit the referenced file if it belongs in the repo;
       (c) convert it to an explicit external link if it is intentionally
       private/external. For `UNLINKED_REF` (a `§` citation), the fix is to add a
       link — **never strip the `§` citation**. When the right target is unclear,
       leave it for the user rather than guessing.
     - For `COLD_READ`: a first-time-reader comprehension gap (undefined term,
       missing step, dangling reference, contradiction, terminology drift,
       unstated prerequisite). The fix is content the author must supply — show
       the quoted stumble and the reader's confusion, propose a concrete
       addition/correction, but treat it as author-owned; do not invent facts.
     - For `MODE_MIXING` (Diátaxis): the doc commits to one mode but embeds
       another. The fix is **structural and needs consent** — propose moving the
       intruding section into its own doc of the right mode (a how-to's
       conceptual detour → a linked `explanation`; a stray reference table → a
       `reference` doc) and leaving a link. Never propose this for a
       README/landing page — those are legitimately multi-mode. Default to a
       link-and-move only when the author agrees the detour interrupts the task.
     - For `INCOMPLETE_FOR_TYPE` (Good Docs): the doc lacks something a reader of
       its type needs (a resolution for each troubleshooting symptom, a
       description for each reference entry, a named prerequisite). The fix is
       content the author supplies — show the blocked reader and propose the
       missing element, but do not invent facts (a resolution or a field's
       meaning must come from the author/code). Never add a section just to
       match a template if no reader is blocked.
   - Ask: "Apply this fix?" Wait for yes/no/skip.
   - On yes, apply the edit.
   - **Lint before commit:** if the edit touches a `.mmd` file or a
     fenced ```mermaid block, run
     `node $SKILL_DIR/scripts/lint-mermaid.mjs <file>`
     and confirm `status: ok`.
   - Commit individually with a message referencing the finding. For
     fixes that touch a single file, include the basename in the subject:
     `docs(<basename>): <imperative summary>`.

## Example: a WALL_OF_TEXT sub-bullet fix

Before — one block asking the reader to hold four things at once:

> The audit runs three lanes, and the first two are fast deterministic scripts
> whose JSON is parsed for findings, while the third is slow because it
> dispatches a subagent per file to judge content drift, missing diagrams, and
> readability, after which every lane's findings are merged and sorted by
> severity into the punch list that /docs-update later parses, so the format has
> to stay regular or the downstream parse breaks.

After — each beat on its own line:

> The audit runs three lanes:
>
> - **Lanes 1–2 (fast):** deterministic scripts whose JSON is parsed for findings.
> - **Lane 3 (slow):** it dispatches a subagent per file to judge content drift,
>   missing diagrams, and readability.
> - **Merge:** every lane's findings are merged and sorted by severity into the
>   punch list that /docs-update later parses.
>
> The format has to stay regular, or the downstream parse breaks.

Every fact is preserved — only the structure and a few connective words changed.

## Stop conditions

- If the user refuses a mechanical fix, skip it and continue with the rest.
- If a fix would require an LLM to invent content (no clear source of truth):
  surface as a "needs manual rewrite" item and do not attempt automatically.
- A `LANE_FAILED` finding means the audit could not inspect a file (a lane
  timed out or returned empty even after retries), not that the file is
  clean. Do not "fix" it — re-run `/docs-audit` on that file, or inspect it
  manually, and only then act on whatever real findings surface.
