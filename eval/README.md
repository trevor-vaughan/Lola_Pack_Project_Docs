# docs-audit evaluation harness

Headless, reproducible evaluation of the `/docs-audit` reviewer lanes. This is
**maintainer research tooling, not part of the installable module** (that lives
under `module/`) and is **not** wired into `task test` — the LLM lanes call the
`claude` CLI headlessly, which costs tokens and needs network, so they are run
by hand when a lane's prompt changes.

## Layout

- `REPORT.md` — the evaluation record: every lane, the fixtures it was measured
  against, and the K=5 results that justify (or reject) wiring it in. Start here.
- `CHANGES.md` — narrative summary of the reworked skill (what changed and why).
- `prompts/<lane>.txt` — the exact prompt each LLM lane is measured with.
- `fixtures/<case>/` — a `DOC.md` (or source tree) plus `expected.json` ground truth.
- `run_<lane>.py` — runs a lane K times against its fixtures and scores recall,
  consistency, and false positives against the ground truth.
- `results/` — captured JSON from prior runs (regenerable).

## Running a lane

Requires the `claude` CLI on `PATH` and the script deps installed once
(`cd ../module/skills/docs-organization/scripts && npm install`).

```bash
python3 run_needsstructure.py     # scannability of procedures (NEEDS_STRUCTURE)
python3 run_missingdemo.py        # hero-demo encouragement (MISSING_DEMO)
python3 run_gooddocs.py           # completeness-for-type (INCOMPLETE_FOR_TYPE)
python3 run_coldread.py fixtures/cold-read grounded 5
```

The discipline: a new LLM lane is validated here (recall on docs that should
flag, anti-nag on docs that should stay silent) **before** it is wired into the
command procedure — see any Round in `REPORT.md`.
