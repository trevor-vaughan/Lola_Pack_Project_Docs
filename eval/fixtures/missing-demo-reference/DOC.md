# Storage engine architecture

This document describes how the storage engine lays out data on disk and how the
write path, compaction, and recovery interact. It is maintainer-facing.

## Write path

Writes land first in an in-memory memtable and are appended to a write-ahead log
for durability. When the memtable exceeds its size threshold it is frozen and
flushed to an immutable on-disk SSTable; a fresh memtable takes over so writes
never block on a flush.

## Compaction

Levelled compaction merges overlapping SSTables to bound read amplification. Each
level holds SSTables with non-overlapping key ranges and a size budget an order of
magnitude larger than the level above it; when a level exceeds its budget, one
SSTable is merged down into the overlapping range of the next level.

## Recovery

On startup the engine replays the write-ahead log from the last checkpoint,
rebuilding the memtable to the exact state before the crash, then resumes normal
operation. Checkpoints are taken after every successful flush so replay is bounded
by one memtable's worth of writes.
