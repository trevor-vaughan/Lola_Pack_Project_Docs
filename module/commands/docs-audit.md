---
description: Find drift between code and documentation — structural, staleness, content, diagrams
argument-hint: ""
---

# /docs-audit

Read-only audit. Surfaces findings; never edits files. Run /docs-update
afterward to act on them.

## User-provided arguments

> $ARGUMENTS

## Instructions

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {
  'primaryColor': '#2f6dab',
  'primaryTextColor': '#1e1e1e',
  'primaryBorderColor': '#7c8ba1',
  'lineColor': '#7c8ba1',
  'edgeLabelBackground': '#eef2f8',
  'tertiaryColor': 'transparent',
  'tertiaryTextColor': '#7c8ba1',
  'tertiaryBorderColor': '#7c8ba1',
  'clusterBkg': 'transparent',
  'clusterBorder': '#7c8ba1',
  'titleColor': '#7c8ba1',
  'noteBkgColor': '#eef2f8',
  'noteTextColor': '#1e1e1e',
  'fontFamily': 'system-ui, sans-serif'
}, 'themeCSS': '.node .nodeLabel{color:#ffffff!important;fill:#ffffff!important;}'}}%%
flowchart TD
  start["invoke /docs-audit"]
  start --> l1["Lane 1: check-structure.sh"]
  l1 --> l2["Lane 2: check-staleness.sh"]
  l2 --> gate{"either exit code 2?"}
  gate -->|yes| stop["surface error and stop"]
  gate -->|no| l3["Lane 3: enumerate in-scope docs"]
  l3 --> sub["dispatch Explore subagents per file"]
  sub --> agg["aggregate findings by lane and severity"]
  agg --> punch["present punch list"]
```

### Locate the docs-organization skill bundle

Before running any script or reading any reference file shipped with the
docs-organization skill, locate the skill bundle on disk by checking these
locations in order and using the first that exists:

1. **Project-local skills directory** for your agent host
   (e.g., `.claude/skills/docs-organization/` under Claude Code, or the
   equivalent project-scoped skills path for your host).
2. **User-global skills directory** for your agent host
   (e.g., `~/.claude/skills/docs-organization/` under Claude Code,
   `~/.config/opencode/skills/docs-organization/` under OpenCode, or
   wherever your host installs user-scoped skill packs).
3. **Plugin-bundled location**, if your host installs skills as part of a
   plugin pack (e.g., `~/.claude/plugins/*/skills/docs-organization/`).
4. **Dev-workspace fallback**: `module/skills/docs-organization/` — this
   only resolves when running inside the pack's own source repository.

Use the agent host's filesystem tools (e.g., `Glob`, or `bash` for `ls`)
to check each candidate. Bind the first existing path to `$SKILL_DIR`.
If more than one candidate exists, prefer the most recently modified — if
that's ambiguous, ask the user which to use. Every `scripts/...` and
`reference/...` path below is relative to `$SKILL_DIR`.

### Steps

1. Read `$SKILL_DIR/SKILL.md` for the invariants and principles this skill enforces. The procedure below is the source of truth for what to do.
2. **Lane 1 — Structural (fast):**
   - Run `bash $SKILL_DIR/scripts/check-structure.sh`.
   - Parse the JSON. Collect findings.
3. **Lane 2 — Staleness (fast):**
   - Run `bash $SKILL_DIR/scripts/check-staleness.sh`.
   - Parse JSON. Collect findings.
4. **Lane 3 — Content and diagram drift (slow, subagent-driven):**
   - Enumerate project documentation files per the scope rules in
     `$SKILL_DIR/SKILL.md` (§ "Scope of audit"). In
     short: `README.md`, every `.md` under `docs/`, and (for skill-pack
     repos) project-shipped docs under `module/`. **Exclude** anything
     matched by `.gitignore`, anything under a dot-directory (`.git/`,
     `.claude/`, `.opencode/`, `.lola/`, etc.), and LLM-configuration
     files (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.cursorrules`).
   - Use the agent host's built-in glob tool (Claude Code: `Glob`), not
     shell `find`, for portability and structured output.
   - For each enumerated file:
     - Dispatch an `Explore`-type subagent with two prompts (separately,
       so findings can be attributed):
       1. **Content drift:** "Read <file>. Identify any specific claims in
          this document that no longer match the code in this repository.
          Return a list of `file:line` citations with what the doc says vs
          what the code actually does. Do not edit any file. Reply in
          under 300 words."
       2. **Missing diagrams (info-level encouragement):** "Read <file>.
          Identify sections that describe one of: a multi-step interaction
          between actors, a state that transitions through phases, a
          system's component layout, a branching decision flow, or data
          shape moving through pipeline stages — and that have no
          accompanying mermaid diagram. For each, return a
          `MISSING_DIAGRAM` finding with the section heading, what kind
          of diagram would fit (flowchart / sequenceDiagram /
          stateDiagram-v2 / erDiagram), and one sentence of justification.
          Severity is info (never blocker). Reply in under 200 words. If
          no candidates exist, return an empty list — do not invent."
   - For each `.mmd` file or fenced ```mermaid block found within the
     enumerated documentation files (same scope rules apply — skip
     dot-directories, gitignored paths, and LLM-config files):
     - Dispatch an `Explore`-type subagent: "Read this diagram and the code
       it depicts. Identify nodes/edges that reference subsystems no longer
       in the code. Reply in under 200 words."
5. Aggregate findings from all three lanes and present a structured
   punch list. **This format is the contract `/docs-update` parses** from
   conversation context, so it must be regular:
   - A one-line summary: counts by severity (e.g., `1 blocker, 0 warnings,
     4 info`).
   - For each non-empty severity, a markdown table with these columns:
     `| Code | File | Line | Note |` where:
     - `Code` is the finding code (e.g., `MISSING_DIAGRAM`,
       `STALE_README`, `MISSING_GITIGNORE_SUPERPOWERS`,
       `MISSING_HOUSE_STYLE_HEADER`).
     - `File` is the repo-relative path.
     - `Line` is the relevant line number, or `—` if not applicable.
     - `Note` carries the data `/docs-update` needs to act on the
       finding:
       - `MISSING_DIAGRAM`: section heading, suggested diagram type
         (`flowchart` / `sequenceDiagram` / `stateDiagram-v2` /
         `erDiagram`), and the one-sentence justification.
       - Content/diagram drift: what the doc claims vs. what the code
         shows, with a code citation.
       - Mechanical codes: usually no extra detail needed.
   - If a finding doesn't fit the schema, list it under a separate
     "Other" subsection rather than mangling the table.
6. **Do not write any files.** Offer: "Run /docs-update to fix these
   findings interactively."

## Stop conditions

- If `check-structure.sh` or `check-staleness.sh` exits 2 (internal error):
  surface the error to the user; do not proceed to Lane 3.
- If Lane 3 subagents fail (timeout, structural error): include those as
  Warning findings ("could not audit X — re-run or inspect manually")
  rather than silently dropping.
