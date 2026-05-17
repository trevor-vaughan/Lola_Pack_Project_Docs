---
description: Independent rubric review of an ADR via subagent, with context isolation
argument-hint: "<NNNN>"
---

# /adr-review

Run an independent subagent review of an existing ADR against the MADR
rubric. The subagent has no access to the current conversation context —
fresh eyes by construction.

## User-provided arguments

> $ARGUMENTS

## Instructions

### Activate the adr skill

Invoke the `adr` skill via your host's Skill tool. The skill's `SKILL.md`
defines `$SKILL_DIR` as the directory the host loaded it from
(`SKILL_DIR=$(dirname "$(realpath <loaded-skill-md>)")`). Reuse `$SKILL_DIR`
for every `scripts/...` and `reference/...` reference below — do not
hardcode `.claude/skills/...` or search candidate paths. When dispatching
subagents, substitute the resolved absolute path of `$SKILL_DIR` into
the subagent prompt — subagents do not inherit your shell variables.

### Steps

1. Read `$SKILL_DIR/SKILL.md` for the invariants and principles this skill enforces. The procedure below is the source of truth for what to do.
2. Resolve the ADR file:
   - Parse NNNN from `$ARGUMENTS` (accept `0001`, `1`, or a full filename).
   - Locate the file under `docs/dev/adr/` or `docs/adr/`.
   - If not found, surface an error.
3. **Dispatch a `general-purpose` subagent** with this self-contained
   prompt (substitute the placeholders before sending):

   ```
   Read the ADR at <absolute path to NNNN-*.md>. Then read the rubric at
   <absolute path to $SKILL_DIR/reference/review-rubric.md>. Apply
   every section of the rubric to the ADR. Reply in under 600 words with
   JSON in this exact shape:

   {
     "passes": ["<section name>", ...],
     "gaps": [
       {
         "section": "<section name>",
         "issue": "<one sentence>",
         "suggestion": "<one or two sentence suggested rewrite>"
       }
     ],
     "overall": "needs-work" | "ready-for-review"
   }
   ```

4. Parse the subagent's JSON. Present passes and gaps to the user.
5. **For each gap:** offer to apply the suggested rewrite. Wait for yes/no
   per gap. If yes, edit the file inline.
6. After all gaps are addressed (or skipped), ask the user: "Update status
   to `reviewed`?" If yes, edit the ADR's frontmatter `status:` field to
   `reviewed`. Do NOT advance to `accepted` automatically — that is a
   separate user decision.
7. Run `bash $SKILL_DIR/scripts/adr-index.sh <adr-dir>` if status
   changed.
8. Commit: `docs(adr): NNNN review (status: reviewed)` if status changed,
   otherwise no commit.

## Stop conditions

- If the subagent returns malformed JSON: surface the raw response and
  ask the user how to proceed.
- If the user rejects every gap: do not advance the status.
