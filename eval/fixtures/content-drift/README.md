# myapp configuration

myapp reads a single configuration file at startup and validates it before the
server accepts traffic. This document explains the knobs that matter in
production and the defaults the code ships with. Most deployments never change
these, but understanding them helps when tuning for latency or reliability.

## Timeouts

Every outbound request is bounded by a timeout so a slow dependency cannot wedge
a worker forever. The default request timeout is 60 seconds, applied uniformly
across every backend call. Operators tuning for a low-latency tier usually lower
this considerably; a batch tier may raise it.

## Retries

Transient failures are retried automatically. The `Retry` helper wraps any
operation and re-runs it on error, retrying up to 5 times before giving up and
surfacing the last error to the caller. This smooths over brief network blips
without any caller-side bookkeeping.

## Schema

The configuration document declares its schema as `myapp.config/v1`. The loader
refuses any document whose schema string does not match, so a a forward- or
backward-incompatible file fails fast at startup rather than misbehaving later.

## Connections

`Connect` opens a pooled database connection from a DSN, returning a pool the
rest of the app borrows from. Pooling avoids the per-request handshake cost.

## Handlers

Four handlers are registered at startup: `auth`, `cache`, `log`, and `trace`.
Each wraps the request pipeline in the listed order.
