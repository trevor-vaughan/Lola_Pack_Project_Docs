# ADR review rubric

When `/adr-review` dispatches a subagent for independent review, that
subagent applies this rubric. Each section either passes or generates a gap
finding with a suggested rewrite.

## Section: Context and Problem Statement

- **Pass criteria:** States the *problem*, not the answer. Identifies real
  constraints. A reader new to the system understands why this decision had
  to be made.
- **Gap signals:** Section is short (< 2 paragraphs), states the chosen
  solution before the alternatives section, refers to constraints without
  naming them.

## Section: Decision Drivers

- **Pass criteria:** At least three named drivers. Each driver is concrete
  enough that you could imagine measuring whether an option satisfies it.
- **Gap signals:** Generic drivers ("simplicity", "performance") without
  qualification. Fewer than two drivers.

## Section: Considered Options

- **Pass criteria:** At least two options other than the chosen one.
  "Do nothing" counts as an option if it's genuinely viable.
- **Gap signals:** Only one option listed. Options are straw men (named but
  obviously dismissed without analysis).

## Section: Decision Outcome

- **Pass criteria:** One clear sentence naming the chosen option. The
  "because" clause ties to one or more decision drivers.
- **Gap signals:** Bulleted list instead of a sentence. Reasoning that
  doesn't connect to the drivers section.

## Section: Consequences

- **Pass criteria:** Both positive AND negative consequences listed. Each
  consequence is specific (not "the system will be better").
- **Gap signals:** Only positive consequences. Vague language like "should
  improve" without saying what or how.

## Section: Pros and Cons of the Options

- **Pass criteria:** Each option has both "Good, because" and "Bad, because"
  entries. The dismissed options have honest reasoning for dismissal.
- **Gap signals:** Dismissed options have only "Bad" entries. Chosen option
  has only "Good" entries.

## Cross-section: Internal consistency

- **Pass criteria:** The decision drivers align with the pros/cons analysis.
  The consequences flow from the chosen option, not from some other.
- **Gap signals:** Drivers mention "latency" but consequences and pros/cons
  don't discuss latency at all.

## Output format

The subagent returns structured findings:

```json
{
  "passes": ["Context and Problem Statement", "Decision Drivers"],
  "gaps": [
    {
      "section": "Considered Options",
      "issue": "Only one alternative listed",
      "suggestion": "Add at least one more option with honest pros/cons"
    }
  ],
  "overall": "needs-work" | "ready-for-review"
}
```
