---
status: proposed
date: 2026-01-14
deciders: platform team
---

> **Illustrative example — not an ADR of this repo.** This is what `/adr-new`
> produces after its inline self-review, shown so authors can see a target.
> The subject project is fictional.

# Use Postgres for primary storage

## Context and Problem Statement

The service currently keeps orders in a single SQLite file. Two teams now write
to it from separate processes, and nightly reporting has begun to block writes
for seconds at a time. We need a primary store that supports concurrent writers
and read replicas before the next product launch adds a third writer.

Doing nothing means the reporting job keeps stalling checkout, which is already
generating support tickets.

## Decision Drivers

- Concurrent writers without file-level lock contention.
- Read replicas for reporting, so analytics never blocks checkout.
- Operational familiarity — the on-call team should already know how to run it.

## Considered Options

- PostgreSQL (managed)
- Keep SQLite, add a write queue in front
- MySQL (managed)

## Decision Outcome

Chosen option: **PostgreSQL (managed)**, because it removes write contention via
MVCC and offers read replicas out of the box, directly satisfying the top two
drivers while staying on tooling the on-call team already runs.

### Consequences

- **Positive:** reporting moves to a replica; checkout writes stop stalling.
  Concurrent writers are handled by the database, deleting the app-side lock code.
- **Negative:** a new managed dependency and its cost; local development now
  needs a Postgres container instead of a bare file.

## Pros and Cons of the Options

### PostgreSQL (managed)

- Good, because MVCC removes the write-lock contention that is causing stalls.
- Good, because managed read replicas satisfy the reporting driver directly.
- Bad, because it adds infrastructure cost and a container to local setup.

### Keep SQLite, add a write queue

- Good, because it avoids a new dependency.
- Bad, because it serializes all writes, which caps throughput as writers grow.
- Bad, because the queue is bespoke code the team must own and debug.

### MySQL (managed)

- Good, because it also offers replicas and concurrent writers.
- Bad, because the on-call team has no MySQL experience, missing the
  familiarity driver.

## More Information

Links to the incident that triggered this, and any follow-up ADR that records
the migration cutover.
