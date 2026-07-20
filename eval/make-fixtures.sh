#!/usr/bin/env bash
# Regenerate deterministic eval fixtures. Each fixture is a self-contained
# directory with planted issues (and planted non-issues) plus an expected.json
# describing the ground truth for scoring.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX="$HERE/fixtures"
rm -rf "$FIX"; mkdir -p "$FIX"

# ---- content-drift fixture: 3 planted drifts + 2 correct claims, buried in prose
mkdir -p "$FIX/content-drift"
cat > "$FIX/content-drift/config.go" <<'GO'
package config

// DefaultTimeout is the per-request timeout.
const DefaultTimeout = 30 // seconds

const SchemaVersion = "myapp.config/v2"

// Retry runs fn up to maxAttempts times (3 total).
func Retry(fn func() error) error {
	const maxAttempts = 3
	var err error
	for i := 0; i < maxAttempts; i++ {
		if err = fn(); err == nil {
			return nil
		}
	}
	return err
}

// Connect opens a pooled database connection.
func Connect(dsn string) (*Pool, error) { return newPool(dsn) }

// Handlers registered at startup.
var Handlers = []string{"auth", "cache", "log", "trace"}
GO
cat > "$FIX/content-drift/README.md" <<'MD'
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
MD
cat > "$FIX/content-drift/expected.json" <<'JSON'
{
  "lane": "content-drift",
  "planted_drift": [
    {"id": "timeout", "doc": "default timeout 60 seconds", "code": "DefaultTimeout = 30"},
    {"id": "retries", "doc": "retries up to 5 times", "code": "maxAttempts = 3"},
    {"id": "schema", "doc": "myapp.config/v1", "code": "myapp.config/v2"}
  ],
  "correct_claims": [
    {"id": "connect", "doc": "Connect opens a pooled db connection"},
    {"id": "handlers", "doc": "four handlers auth cache log trace"}
  ]
}
JSON

# ---- readability fixture: wall-of-text + dense bullet + long section + clean
mkdir -p "$FIX/readability"
{
  echo '# Readability fixture'
  echo
  echo '## Clean'
  echo
  echo 'A short paragraph. It has two sentences.'
  echo
  echo '## Wall'
  echo
  # one long paragraph (>120 words)
  printf 'This paragraph is deliberately long. '
  for i in $(seq 1 40); do printf 'Sentence %s about the subsystem behaviour and its many interacting parts. ' "$i"; done
  echo
  echo
  echo '## Bullets'
  echo
  printf -- '- **Fat.** '
  for i in $(seq 1 30); do printf 'clause %s of a very long flat bullet with lots of detail, ' "$i"; done
  echo 'end.'
  echo '- a short tight bullet'
} > "$FIX/readability/DOC.md"
cat > "$FIX/readability/expected.json" <<'JSON'
{"lane": "readability", "expect_codes": ["WALL_OF_TEXT", "DENSE_BULLET"]}
JSON

# ---- diagram fixture: branchy flow (should suggest) vs linear list (should not)
mkdir -p "$FIX/diagram-branchy"
cat > "$FIX/diagram-branchy/DOC.md" <<'MD'
# State machine

## Lifecycle

A record begins in `pending`. From `pending` it either advances to `active`
when validation passes, or falls to `rejected` when it fails. An `active`
record can be `suspended` and later resumed back to `active`, or it can expire
to `archived`. A `suspended` record that is not resumed within the window also
expires to `archived`. From `archived` there is no return; a `rejected` record
may be resubmitted, which sends it back to `pending`.
MD
echo '{"lane":"diagram","expect_missing_diagram":true}' > "$FIX/diagram-branchy/expected.json"

mkdir -p "$FIX/diagram-linear"
cat > "$FIX/diagram-linear/DOC.md" <<'MD'
# Install

## Steps

1. Download the archive.
2. Extract it to `/opt/app`.
3. Run `./install.sh`.
4. Add `/opt/app/bin` to your `PATH`.
MD
echo '{"lane":"diagram","expect_missing_diagram":false}' > "$FIX/diagram-linear/expected.json"

echo "fixtures written to $FIX"
find "$FIX" -type f | sort
